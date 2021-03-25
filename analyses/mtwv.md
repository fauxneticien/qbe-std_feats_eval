Maximum Term Weighted Value
================
Nay San
25 March, 2021

## Setup

### R environment

``` r
if (!"pacman" %in% installed.packages()) install.packages("pacman")

pacman::p_load(
  # Use here() to make paths relative from directory containing
  # 'qbe-std_feats_eval.Rproj' (i.e. project root)
  ggplot2,
  ggthemes,
  here,
  knitr,
  purrr,
  dplyr,
  readr,
  stringr,
  tidyr
)

source(here("analyses/plot_mtwvs.R"))
```

## Main experiment MTWVs

``` r
main_mtwv_df <- read_csv(
  file = here("analyses/data/main-all_mtwv.csv"),
  col_types = "ccdddd"
)

# Show mtwv_df in Markdown document
head(main_mtwv_df) %>%
  kable()
```

| dataset | features                            |   mtwv |   p\_fa | p\_miss | desc\_score |
| :------ | :---------------------------------- | -----: | ------: | ------: | ----------: |
| eng-mav | 20210225-Large-0FT\_encoder         | 0.6526 | 0.07715 |   0.079 |   0.8254625 |
| eng-mav | 20210225-Large-0FT\_quantizer       | 0.6216 | 0.09962 |   0.031 |   0.6775565 |
| eng-mav | 20210225-Large-0FT\_transformer-L01 | 0.6711 | 0.06929 |   0.087 |   0.7979993 |
| eng-mav | 20210225-Large-0FT\_transformer-L02 | 0.6756 | 0.06315 |   0.104 |   0.8107488 |
| eng-mav | 20210225-Large-0FT\_transformer-L03 | 0.6788 | 0.05492 |   0.130 |   0.8187936 |
| eng-mav | 20210225-Large-0FT\_transformer-L04 | 0.6954 | 0.07783 |   0.033 |   0.7819498 |

### All MTWVs plotted

``` r
plot_mtwvs(main_mtwv_df)
```

![](mtwv_files/figure-gfm/Main%20MTWVs%20plot-1.png)<!-- -->

### Reported numbers

#### Baseline performance (MFCC and BNF)

``` r
main_mtwv_df %>%
    mutate(
      baseline = str_extract(features, "(mfcc|bnf)"),
      mtwv     = round(mtwv, 2)
    ) %>%
    filter(!is.na(baseline)) %>%
    select(baseline, dataset, mtwv) %>%
    spread(baseline, mtwv) %>%
    arrange(desc(mfcc)) %>% 
    select(dataset, mfcc, bnf) %>% 
    kable()
```

| dataset  | mfcc |  bnf |
| :------- | ---: | ---: |
| wrm-pd   | 0.83 | 0.71 |
| gbb-pd   | 0.72 | 0.61 |
| eng-mav  | 0.65 | 0.66 |
| pjt-sw01 | 0.56 | 0.61 |
| gbb-lg   | 0.50 | 0.53 |
| wrl-mb   | 0.48 | 0.36 |
| gos-kdl  | 0.36 | 0.37 |
| gup-wat  | 0.33 | 0.31 |
| wbp-jk   | 0.18 | 0.27 |
| mwf-jm   | 0.14 | 0.28 |

##### Baseline means

``` r
main_mtwv_df %>%
    filter(str_detect(features, "(mfcc|bnf)")) %>% 
    group_by(features) %>%
    summarise(mean_mtwv = round(mean(mtwv), 3)) %>%
    arrange(mean_mtwv) %>%
    kable()
```

| features | mean\_mtwv |
| :------- | ---------: |
| bnf      |      0.472 |
| mfcc     |      0.475 |

#### wav2vec 2.0 middle Transformer layers

``` r
main_mtwv_df %>%
    filter(str_detect(features, "transformer-L1[0-4]")) %>% 
    group_by(features) %>%
    summarise(mean_mtwv = round(mean(mtwv), 3)) %>%
    arrange(mean_mtwv) %>%
    kable()
```

| features                            | mean\_mtwv |
| :---------------------------------- | ---------: |
| 20210225-Large-0FT\_transformer-L14 |      0.618 |
| 20210225-Large-0FT\_transformer-L10 |      0.646 |
| 20210225-Large-0FT\_transformer-L13 |      0.654 |
| 20210225-Large-0FT\_transformer-L12 |      0.664 |
| 20210225-Large-0FT\_transformer-L11 |      0.680 |

#### Improvement on wbp-jk and mwf-jm

``` r
main_mtwv_df %>%
  filter(
    dataset %in% c("wbp-jk", "mwf-jm"),
    str_detect(features, "(bnf|L11)")
  ) %>%
  select(dataset, features, mtwv) %>%
  mutate(mtwv = round(mtwv, 2)) %>% 
  spread(features, mtwv) %>%
  select(dataset, bnf, w2v2_T11 = `20210225-Large-0FT_transformer-L11`) %>%
  mutate(
    percent_improvement = round((w2v2_T11 - bnf)/bnf * 100, 0)
  ) %>%
  arrange(percent_improvement) %>% 
  kable()
```

| dataset |  bnf | w2v2\_T11 | percent\_improvement |
| :------ | ---: | --------: | -------------------: |
| wbp-jk  | 0.27 |      0.42 |                   56 |
| mwf-jm  | 0.28 |      0.52 |                   86 |

#### w2v2-T11 performance, Gronings vs. Australian languages

``` r
main_mtwv_df %>%
  filter(
    dataset != "eng-mav",
    str_detect(features, "L11")
  ) %>%
  select(dataset, features, mtwv) %>%
  mutate(mtwv = round(mtwv, 2)) %>% 
  arrange(desc(mtwv)) %>%
  kable()
```

| dataset  | features                            | mtwv |
| :------- | :---------------------------------- | ---: |
| gbb-pd   | 20210225-Large-0FT\_transformer-L11 | 0.85 |
| wrm-pd   | 20210225-Large-0FT\_transformer-L11 | 0.85 |
| gbb-lg   | 20210225-Large-0FT\_transformer-L11 | 0.73 |
| gos-kdl  | 20210225-Large-0FT\_transformer-L11 | 0.73 |
| pjt-sw01 | 20210225-Large-0FT\_transformer-L11 | 0.66 |
| wrl-mb   | 20210225-Large-0FT\_transformer-L11 | 0.58 |
| gup-wat  | 20210225-Large-0FT\_transformer-L11 | 0.56 |
| mwf-jm   | 20210225-Large-0FT\_transformer-L11 | 0.52 |
| wbp-jk   | 20210225-Large-0FT\_transformer-L11 | 0.42 |
