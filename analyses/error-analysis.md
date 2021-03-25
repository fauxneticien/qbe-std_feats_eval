Error analysis
================
Nay San
25 March, 2021

## About

## Setup

### R environment

``` r
if (!"pacman" %in% installed.packages()) install.packages("pacman")

pacman::p_load(
  # Use here() to make paths relative from directory containing
  # 'qbe-std_feats_eval.Rproj' (i.e. project root)
  dplyr,
  here,
  knitr,
  purrr,
  readr,
  stringr,
  tidyr
)
```

### Data

#### Get list of ‘unretrievable’ queries

We define a query as ‘unretrievable’ if the there are no true matches
for that query in the ranked results returned by the top performing
system using features extracted from the wav2vec 2.0 Transformer layer
11. The search results for each of the Australian language datasets are
provided for convenience in the `analyses/data` directory
(e.g. `analyses/data/20210225-Large-0FT_transformer-L11_wrl-mb.csv`).

``` r
T11_results <- here("analyses/data") %>%
  list.files(
    pattern = "20210225-Large-0FT_transformer-L11",
    full.names = TRUE
  ) %>%
  map_df(function(csv_path) {
    
    csv_file <- basename(csv_path)
    dataset  <- str_extract(csv_file, "L11_.*?\\.csv$") %>%
      str_remove("L11_") %>%
      str_remove("\\.csv")
    
    read_csv(csv_path, col_types = "ccid") %>%
      mutate(dataset = dataset)
    
  })

unretrievable_qs <- T11_results %>% group_by(query) %>%
    slice_max(order_by = prediction, n = 5) %>%
    group_by(query) %>%
    filter(!1 %in% label) %>%
    slice_max(order_by = prediction, n = 1) %>% 
    arrange(dataset, query, reference)

head(unretrievable_qs) %>%
  kable()
```

| query                   | reference     | label | prediction | dataset |
| :---------------------- | :------------ | ----: | ---------: | :------ |
| ahenge\_AR\_3cf4f2f2    | LGK-CD2-18-30 |     0 |  0.8993790 | gbb-lg  |
| aherne\_AR\_3e50bcbb    | LGK-CD2-18-25 |     0 |  0.9801268 | gbb-lg  |
| akarre\_AR\_7826d413    | LGK-CD1-24-18 |     0 |  0.9523285 | gbb-lg  |
| akepe\_AR\_226e79e      | LGK-CD2-15-09 |     0 |  0.9582227 | gbb-lg  |
| akeyalthe\_AR\_7426ada2 | LGK-CD1-33-30 |     0 |  0.9725204 | gbb-lg  |
| akwerre\_AR\_29270d09   | LGK-CD2-21-16 |     0 |  0.9098956 | gbb-lg  |

#### Transcribe and annotate difference between query and top match

Using the list of unretrievable queries and their top match listed
above, we re-ran the DTW search for each pair, noting down the time
frame at which the minimal distance occurred, and examining the source
wav file of the reference at that time range. In consultation with the
ground truth texts, we then transcribed the query and the matched
region, and the differences between the query and the match. These
annotations are shown in the table below.

``` r
errors <- read_csv(
    file = "data/error-analysis.csv",
    col_types = "ccccddcccdc"
  )

kable(head(errors, 5))
```

| qm\_transcribed | differences | query\_text | match\_text | match\_start | match\_end | dataset | query                  | reference     | ref\_dur | ref\_text                        |
| :-------------- | :---------- | :---------- | :---------- | -----------: | ---------: | :------ | :--------------------- | :------------ | -------: | :------------------------------- |
| aŋe; ane        | \[ŋ, n\]    | ahenge      | ahene       |         0.34 |       1.17 | gbb-lg  | ahenge\_AR\_3cf4f2f2   | LGK-CD2-18-30 |     3.11 | ahene aheneynenke                |
| aɳe; ane        | \[ɳ, n\]    | aherne      | ahene       |         0.32 |       0.91 | gbb-lg  | aherne\_AR\_3e50bcbb   | LGK-CD2-18-25 |     3.04 | ahene ahenarrenke                |
| akaɾe; aɾkaɾe   | \[\_, ɾ\]   | akarre      | arrkarre    |         1.21 |       1.86 | gbb-lg  | akarre\_AR\_7826d413   | LGK-CD1-24-18 |     2.23 | arwele tharrkarre                |
| ilence; ilenke  | \[c, k\]    | ilentye     | ilenke      |         3.01 |       3.95 | gbb-lg  | ilentye\_AR\_80e95e1b  | LGK-CD1-30-01 |     4.68 | Kwere-penhe arntwelke re eylenke |
| aŋkenke; aŋkene | \[k, \_\]   | angkenke    | angkene     |         0.69 |       1.17 | gbb-lg  | angkenke\_AR\_12a322f2 | LGK-CD1-15-05 |     1.50 | kartarte nge angkene             |

### Statistics

In this section, we derive the statistics reported in the paper.

#### Total number of unretrievable queries

``` r
errors %>%
  nrow()
```

    ## [1] 119

#### Number of differences

``` r
diffs <- errors %>%
    separate_rows(differences, sep = "; ") %>%
    # Filter out uninterpretable errors (too many differences)
    filter(!is.na(differences))

diffs %>%
    group_by(dataset, query) %>%
    tally(name = "n_differences") %>%
    group_by(n_differences) %>%
    tally(name = "count") %>%
    ungroup %>% 
    mutate(
      totals  = sum(count),
      percent = count/totals * 100
    ) %>% 
    kable()
```

| n\_differences | count | totals |  percent |
| -------------: | ----: | -----: | -------: |
|              1 |    20 |     89 | 22.47191 |
|              2 |    33 |     89 | 37.07865 |
|              3 |    25 |     89 | 28.08989 |
|              4 |    11 |     89 | 12.35955 |

#### Substitutions

``` r
subs <- diffs %>%
    filter(!str_detect(differences, "(\\[_|_\\])")) %>% # Filter out insertions and deletions
    mutate(
        sub_type = ifelse(str_detect(differences, "(a|e|ə|i|ɪ|ɔ|u|ʊ)"), "Vowel", "Consonant"),
        stress = ifelse(str_detect(differences, "'"), "Stressed", "Unstressed")
    ) 
```

##### Consonantal substitutions

``` r
subs %>% 
    group_by(sub_type, stress) %>%
    tally(name = "count") %>%
    ungroup %>% 
    mutate(
      totals  = sum(count),
      percent = count/totals * 100
    ) %>% 
    kable()
```

| sub\_type | stress     | count | totals |  percent |
| :-------- | :--------- | ----: | -----: | -------: |
| Consonant | Unstressed |   128 |    193 | 66.32124 |
| Vowel     | Stressed   |    27 |    193 | 13.98964 |
| Vowel     | Unstressed |    38 |    193 | 19.68912 |

##### Vocalic substitutions

``` r
subs %>% 
    filter(sub_type == "Vowel") %>% 
    group_by(stress) %>%
    tally(name = "count") %>%
    ungroup %>% 
    mutate(
      totals  = sum(count),
      percent = count/totals * 100
    ) %>% 
    kable()
```

| stress     | count | totals |  percent |
| :--------- | ----: | -----: | -------: |
| Stressed   |    27 |     65 | 41.53846 |
| Unstressed |    38 |     65 | 58.46154 |
