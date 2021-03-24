suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(purrr))
library(stringr)
library(readr)

list.files(
  path    = ".",
  pattern = "score.mtwv.txt",
  recursive = TRUE,
  full.names = TRUE
) %>% 
  map_df(function(score_txt_path) {
    
    # Get last 2 parent directories
    #
    # /path/to/data/processed/STDEval/_dataset_/_features_/score.mtwv.txt
    # -> c("_dataset_", "_features_")
    path_components <- score_txt_path %>%
      str_remove("[/|\\\\]score.mtwv.txt$") %>%
      str_split("/|\\\\") %>%
      unlist() %>%
      tail(2)
    
    dataset  <- path_components[1]
    features <- path_components[2]
    
    txt_lines <- readLines(score_txt_path)
    # Find which line starts with '|      ALL ....'
    all_line  <- which(str_detect(txt_lines, "^\\|\\s+ALL"))
    mtwv_txt  <- txt_lines[all_line]
    
    mtwv_vals <- mtwv_txt %>%
      str_extract_all("(\\d|\\.)+") %>%
      unlist()
    
    tibble(
      dataset    = dataset,
      features   = features,
      mtwv       = as.double(mtwv_vals[1]),
      p_fa       = as.double(mtwv_vals[3]),
      p_miss     = as.double(mtwv_vals[4]),
      desc_score = as.double(mtwv_vals[5])
    )
    
  }) %>%
  write_csv("all_mtwv.csv")

message("Gathered MTWVs written to all_mtwv.csv")
