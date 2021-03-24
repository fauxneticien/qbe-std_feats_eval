#!/usr/bin/env Rscript

# Prep dataset labels and DTW files for use with the NIST STDEval tool
#  
# Example usage:
#
# Rscript scripts/prep_STDEval.R data/raw/datasets data/processed/dtw data/processed/STDEval
args = commandArgs(trailingOnly=TRUE)

# For debugging:
# args = c("data/raw/datasets", "data/processed/dtw", "data/processed/STDEval")
datasets_path <- args[1]
dtw_csvs_path <- args[2]
stdeval_path  <- args[3]

stopifnot(dir.exists(datasets_path))
stopifnot(dir.exists(dtw_csvs_path))

if(!dir.exists(stdeval_path)) dir.create(stdeval_path)

if(!dir.exists(file.path(stdeval_path, "STDEval-0.7"))) {
  cp_stdeval_tool <- file.copy(
    from = "scripts/STDEval-0.7",
    to   = stdeval_path,
    recursive = TRUE
  )
  
  gather_script <- file.copy(
    from = "scripts/gather_mtwv.R",
    to   = stdeval_path
  )
}

suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(glue))
suppressPackageStartupMessages(library(furrr))
library(readr)
library(stringr)
library(tuneR)

# Define helper functions

make_std_eval_command <- function(dataset, system, prior = 0.0279, cost_false_alarm = 1, cost_missed_detection = 10) {
  
  glue('
perl -I STDEval-0.7/src STDEval-0.7/src/STDEval.pl
-s {dataset}/{system}/*.stdlist.xml -number-trials-per-sec=1
-e {dataset}/*.ecf.xml
-r {dataset}/*.rttm
-t {dataset}/*.tlist.xml
-A -o {dataset}/{system}/score.mtwv.txt
-d {dataset}/{system}/score.det
-S 2.0 -F 0.5
-p {signif(prior, 3)}
-k {cost_false_alarm}
-K {cost_missed_detection} >& {dataset}/{system}/score.log\n
') %>%
# Remove non-final newlines (GNU Parallel wants 1 command per line)
str_replace_all("\n(?!$)", " ") 

}

make_ecf_file <- function(dataset, labels_df, output_ecf_path) {
  
  refs_df <- labels_df %>%
    distinct(reference, ref_dur)
  
  ecf_body  <- refs_df %>%
    glue_data('<excerpt audio_filename="{reference}.wav" channel="1" tbeg="0.000" dur="{ref_dur}" language="multiple" source_type="{dataset}" />') %>%
    paste0(collapse = "\n")
  
  ecf_xml <- glue('
<?xml version="1.0" encoding="UTF-8"?>
<ecf source_signal_duration="{sum(refs_df$ref_dur)}" version="20130512-1800">
{ecf_body}
</ecf>
  ')
  
  writeLines(ecf_xml, output_ecf_path)
  
}

make_tlist_file <- function(dataset, labels_df, output_tlist_path) {
  
  queries_df <- labels_df %>%
    distinct(query)
  
  tlist_body <- queries_df %>%
    glue_data('<term termid="{query}"><termtext>{query}</termtext></term>') %>%
    paste0(collapse = "\n")
  
  tlist_xml <- glue('
<?xml version="1.0" encoding="UTF-8"?>
<termlist ecf_filename="{dataset}.ecf.xml" language="multiple" version="20130512-1500">
{tlist_body}
</termlist>
  ')
  
  writeLines(tlist_xml, output_tlist_path)
  
}

make_rttm_file <- function(labels_df, output_rttm_path) {
  
  occurrence_df <- labels_df %>%
    filter(label == 1) %>%
    group_by(reference, ref_dur) %>%
    summarise(queries = list(query), .groups = 'drop')
  
  rttm_lines <- pmap_chr(list(occurrence_df$reference, occurrence_df$ref_dur, occurrence_df$queries), function(ref, dur, qlist) {
    
    spk_line   <- glue('SPEAKER {ref} 1 0.000 {format(dur, nsmall=3)} <NA> <NA> SELF <NA>')
    lex_line   <- glue('LEXEME {ref} 1 0.000 {format(dur, nsmall=3)} NO_KEYWORD lex SELF <NA>')
    
    term_lines <- data.frame(query = qlist) %>%
      glue_data('LEXEME {ref} 1 0.000 {format(dur, nsmall=3)} {query} lex SELF <NA>') %>%
      paste0(collapse = "\n")
    
    paste(spk_line, term_lines, sep = "\n")
    
  }) %>%
  paste0(collapse = "\n")
  
  writeLines(rttm_lines, output_rttm_path)
  
}

make_stdlist_file <- function(dataset, dtw_results_df, output_stdlist_path) {
  
  stdlist_body <- dtw_results_df %>%
    split(dtw_results_df$query) %>%
    map_chr(function(refs_df) {
      
      refs_body <- refs_df %>%
        glue_data('<term file="{reference}" channel="1" tbeg="0" dur="{ref_dur}" score="{prediction}" decision="{ifelse(label==1, "YES", "NO")}"/>') %>%
        paste0(collapse = "\n")
      
      glue('
<detected_termlist termid="{refs_df$query[1]}" term_search_time="0.0" oov_term_count="0">
{refs_body}
</detected_termlist>
      ')
      
    }) %>%
    paste0(collapse = "\n")  
  
  stdlist_xml <- glue('
<?xml version="1.0" encoding="UTF-8"?>
<stdlist termlist_filename="{dataset}.tlist.xml" indexing_time="0.0" language="multiple" index_size="0" system_id="example">
{stdlist_body}
</stdlist>
')
  
  writeLines(stdlist_xml, output_stdlist_path)

}

get_wav_dur <- function(wav_file) {
  audio <- readWave(wav_file, header=TRUE)
  round(audio$samples / audio$sample.rate, 2)
}

# STDEval really does not like non-ASCII characters
convert_accents <- function(gos_text) {
  
  gos_text %>%
    str_replace_all("è", "iG") %>%
    str_replace_all("ì", "oG") %>% 
    str_replace_all("ò", "eG") %>% 
    str_replace_all("(ö|ö)", "oE")
  
}

# Create empty file to append to
stdeval_cmds_file <- file.path(stdeval_path, "stdeval_commands.txt")
cat("", file = stdeval_cmds_file)

message("Preparing files for STDEval tool...")

suppressWarnings(plan(multisession))

output <- list.files(datasets_path) %>%
  future_map(
    .progress = TRUE,
    .f = function(dataset) {
    
    ref_wavs <- list.files(file.path(datasets_path, dataset, "references"), pattern = "\\.wav", full.names = TRUE)
    ref_durs  <- map_dbl(ref_wavs, get_wav_dur) 
    
    ref_durs_df <- tibble(
      reference = str_remove(basename(ref_wavs), "\\.wav") %>% convert_accents(),
      ref_dur   = ref_durs
    )
    
    labels_csv  <- file.path(datasets_path, dataset, "labels.csv")
    labels_df   <- read_csv(labels_csv, col_types = "cci") %>%
      mutate(
        query = convert_accents(query),
        reference = convert_accents(reference)
      ) %>% 
      left_join(ref_durs_df, by = "reference")
    
    output_path <- file.path(stdeval_path, dataset)

    if(!dir.exists(output_path)) dir.create(output_path)

    ecf_file   <- file.path(output_path, paste(dataset, "ecf", "xml", sep = "."))
    tlist_file <- file.path(output_path, paste(dataset, "tlist", "xml", sep = "."))
    rttm_file  <- file.path(output_path, paste(dataset, "rttm", sep = "."))

    make_ecf_file(dataset, labels_df, ecf_file)
    make_tlist_file(dataset, labels_df, tlist_file)
    make_rttm_file(labels_df, rttm_file)
    
    list.files(dtw_csvs_path, pattern = dataset, full.names = TRUE) %>%
      walk(function(dtw_csv_path) {
        
        dtw_results_df <- read_csv(dtw_csv_path, col_types = "ccid") %>%
          mutate(
            query = convert_accents(query),
            reference = convert_accents(reference)
          ) %>% 
          left_join(ref_durs_df, by = "reference")
        
        feats  <- basename(dtw_csv_path) %>% 
          str_remove(dataset) %>% 
          str_remove("_\\.csv")
        
        feats_dir <- file.path(output_path, feats)
        
        if(!dir.exists(feats_dir)) dir.create(feats_dir)
        
        stdlist_file <- file.path(feats_dir, paste(feats, "stdlist", "xml", sep = "."))
        
        make_stdlist_file(dataset, dtw_results_df, stdlist_file)
        
        make_std_eval_command(
          dataset,
          feats
        ) %>% 
        cat(file = stdeval_cmds_file, append = TRUE)
        
      })
    
  })
  
  