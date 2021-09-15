library(tidyverse)
library(here)

dtw_folder     <- here("data/processed/dtw")
STDEval_folder <- here("data/processed/STDEval_pub")

all_mtwv_file <- here("analyses/data/all_mtwv.csv")

all_mtwv_df   <- read_csv(all_mtwv_file) %>%
  filter(str_detect(features, "(bnf|L11)"))

fa_cost   <- 1
miss_cost <- 10
prior     <- 0.0279
beta      <- (fa_cost/miss_cost)*((1/prior) - 1)

mtwv_by_queries <- 
  pmap_df(
    .l = list(all_mtwv_df$dataset, all_mtwv_df$features, all_mtwv_df$desc_score),
    .f = function(dataset, features, desc_score) {
      
      dtw_file  <- file.path(dtw_folder, paste(features, "_", dataset, ".csv", sep = ""))
      stopifnot(file.exists(dtw_file))
      
      scorefile <- file.path(STDEval_folder, dataset, features, "score.mtwv.txt")
      stopifnot(file.exists(scorefile))
      
      scorefile <- readLines(scorefile)
      
      N_trials <- scorefile %>%
        keep(~ str_detect(., "Total Speech Time")) %>%
        str_extract("\\d+") %>%
        as.integer()
      
      read_csv(dtw_file, col_types = "ccid") %>%
        mutate(hard_pred = prediction >= desc_score) %>%
        group_by(query) %>%
        summarise(
          ref  = sum(label),
          corr = sum(label == 1 & hard_pred == 1),
          fa   = sum(label == 0 & hard_pred == 1),
          miss = sum(label == 1 & hard_pred == 0)
        ) %>%
        mutate(
          p_fa   = (fa/(N_trials - corr)),
          p_miss = 1 - (corr/ref),
          mtwv   = 1 - (p_miss + (beta * p_fa)),
          dataset = dataset,
          features = features
        ) %>%
        select(features, dataset, query, ref:mtwv)
        
      
    }
  ) 
