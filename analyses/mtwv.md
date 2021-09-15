Maximum Term Weighted Value
================
Nay San
14 September, 2021

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
  tidyr,
  broom
)

source(here("analyses/plot_mtwvs.R"))
```

## All MTWVs

``` r
mtwv_df <- read_csv(
  file = here("analyses/data/all_mtwv.csv"),
  col_types = "ccdddd"
)

# Show mtwv_df in Markdown document
head(mtwv_df) %>%
  kable()
```

| dataset | features                            |   mtwv |   p\_fa | p\_miss | desc\_score |
|:--------|:------------------------------------|-------:|--------:|--------:|------------:|
| eng-mav | 20210225-Large-0FT\_encoder         | 0.6526 | 0.07715 |   0.079 |   0.8254625 |
| eng-mav | 20210225-Large-0FT\_quantizer       | 0.6216 | 0.09962 |   0.031 |   0.6775565 |
| eng-mav | 20210225-Large-0FT\_transformer-L01 | 0.6711 | 0.06929 |   0.087 |   0.7979993 |
| eng-mav | 20210225-Large-0FT\_transformer-L02 | 0.6756 | 0.06315 |   0.104 |   0.8107488 |
| eng-mav | 20210225-Large-0FT\_transformer-L03 | 0.6788 | 0.05492 |   0.130 |   0.8187936 |
| eng-mav | 20210225-Large-0FT\_transformer-L04 | 0.6954 | 0.07783 |   0.033 |   0.7819498 |

### All MTWVs plotted (Fig. 2 in paper)

``` r
mtwv_df %>%
  filter(str_detect(features, "(bnf|mfcc|Large)")) %>%
  plot_mtwvs(wav2vec_checkpoint_name = "wav2vec 2.0 Large (LibriSpeech 960h)")
```

![](mtwv_files/figure-gfm/Main%20MTWVs%20plot-1.png)<!-- -->

``` r
mtwv_df %>%
  filter(str_detect(features, "(bnf|mfcc|xlsr)")) %>%
  plot_mtwvs(wav2vec_checkpoint_name = "wav2vec 2.0 Large (XLSR53)")
```

![](mtwv_files/figure-gfm/XLSR53%20MTWVs%20plot-1.png)<!-- -->

### Reported numbers

#### Baseline performance (MFCC and BNF)

``` r
mtwv_df %>%
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
|:---------|-----:|-----:|
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

#### Improvement on wbp-jk and mwf-jm

``` r
mtwv_df %>%
  filter(
    dataset %in% c("wbp-jk", "mwf-jm"),
    str_detect(features, "(bnf|Large-0FT_transformer-L11)")
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
|:--------|-----:|----------:|---------------------:|
| wbp-jk  | 0.27 |      0.42 |                   56 |
| mwf-jm  | 0.28 |      0.52 |                   86 |

#### Means and standard deviations of BNF, LS960-T11 and XLSR53-T11 (Table 2 in paper)

``` r
mtwv_by_queries <- read_csv(
  here("analyses/data/mtwv_by_queries.csv"),
  col_types = "ccciiiiddd"
  )

mtwv_by_queries %>%
  group_by(dataset, features) %>%
  summarise(
    mean = mean(mtwv),
    sd = sd(mtwv),
    .groups = "keep"
  ) %>%
  mutate(stat = paste(signif(mean, 3), " (", signif(sd, 3), ")", sep = "")) %>%
  select(dataset, features, stat) %>%
  spread(features, stat) %>%
  select(dataset, bnf, `20210225-Large-0FT_transformer-L11`, `wav2vec2-large-xlsr-53_transformer-L11`) %>%
  kable()
```

| dataset  | bnf            | 20210225-Large-0FT\_transformer-L11 | wav2vec2-large-xlsr-53\_transformer-L11 |
|:---------|:---------------|:------------------------------------|:----------------------------------------|
| eng-mav  | 0.656 (0.0781) | 0.894 (0.222)                       | 0.794 (0.248)                           |
| gbb-lg   | 0.533 (0.36)   | 0.733 (0.338)                       | 0.719 (0.327)                           |
| gbb-pd   | 0.612 (0.383)  | 0.849 (0.248)                       | 0.803 (0.309)                           |
| gos-kdl  | 0.372 (0.335)  | 0.728 (0.281)                       | 0.647 (0.306)                           |
| gup-wat  | 0.313 (0.271)  | 0.561 (0.266)                       | 0.483 (0.292)                           |
| mwf-jm   | 0.279 (0.33)   | 0.515 (0.365)                       | 0.435 (0.346)                           |
| pjt-sw01 | 0.607 (0.163)  | 0.66 (0.21)                         | 0.572 (0.207)                           |
| wbp-jk   | 0.267 (0.353)  | 0.422 (0.356)                       | 0.468 (0.325)                           |
| wrl-mb   | 0.352 (0.213)  | 0.573 (0.309)                       | 0.379 (0.308)                           |
| wrm-pd   | 0.713 (0.361)  | 0.853 (0.256)                       | 0.843 (0.26)                            |

#### One-sided paired t-tests

``` r
t_test_func <- function(greater_hyp, less_hyp) {
  
  mtwv_by_queries %>%
    filter(features %in% c(greater_hyp, less_hyp)) %>%
    split(.$dataset) %>%
    imap_dfr(function(xlsr_vs_mono, dataset) {
    
    t_test_ds <- xlsr_vs_mono %>%
      select(features, mtwv, query) %>%
      spread(features, mtwv)
    
    gt_hyp_vals <- pull(t_test_ds[, greater_hyp])
    lt_hyp_vals <- pull(t_test_ds[, less_hyp])
    
    t.test(
      x = gt_hyp_vals,
      y = lt_hyp_vals,
      alternative = "greater",
      paired = TRUE
    ) %>% 
      tidy() %>%
      mutate(
        dataset = dataset,
        p.value = round(p.value, 3),
        gt_mean = mean(gt_hyp_vals),
        lt_mean = mean(lt_hyp_vals)
      ) %>% 
    select(dataset, gt_mean, lt_mean, dof = parameter, diff = estimate, t.value = statistic, p.value)
    
  })
  
}
```

##### 20210225-Large-0FT\_transformer-L11 vs. BNF

``` r
t_test_func(
    greater_hyp = "20210225-Large-0FT_transformer-L11",
    less_hyp = "bnf"
  ) %>%
  kable()
```

| dataset  |  gt\_mean |  lt\_mean | dof |      diff |   t.value | p.value |
|:---------|----------:|----------:|----:|----------:|----------:|--------:|
| eng-mav  | 0.8935692 | 0.6558279 |  99 | 0.2377413 | 11.158383 |   0.000 |
| gbb-lg   | 0.7334673 | 0.5325228 | 156 | 0.2009445 |  6.723896 |   0.000 |
| gbb-pd   | 0.8493772 | 0.6122436 | 396 | 0.2371337 | 14.123910 |   0.000 |
| gos-kdl  | 0.7282060 | 0.3716564 |  82 | 0.3565496 |  9.775838 |   0.000 |
| gup-wat  | 0.5610876 | 0.3130238 |  49 | 0.2480638 |  6.638191 |   0.000 |
| mwf-jm   | 0.5153840 | 0.2793821 |  36 | 0.2360018 |  4.806541 |   0.000 |
| pjt-sw01 | 0.6599793 | 0.6071204 |  29 | 0.0528589 |  1.409121 |   0.085 |
| wbp-jk   | 0.4216062 | 0.2669110 |  23 | 0.1546952 |  1.866983 |   0.037 |
| wrl-mb   | 0.5725867 | 0.3519695 |  22 | 0.2206173 |  3.024191 |   0.003 |
| wrm-pd   | 0.8525557 | 0.7133387 | 382 | 0.1392170 |  8.666956 |   0.000 |

##### wav2vec2-large-xlsr-53\_transformer-L11 vs. BNF

``` r
t_test_func(
    greater_hyp = "wav2vec2-large-xlsr-53_transformer-L11",
    less_hyp = "bnf"
  ) %>%
  kable()
```

| dataset  |  gt\_mean |  lt\_mean | dof |       diff |    t.value | p.value |
|:---------|----------:|----------:|----:|-----------:|-----------:|--------:|
| eng-mav  | 0.7942569 | 0.6558279 |  99 |  0.1384290 |  5.6917932 |   0.000 |
| gbb-lg   | 0.7190475 | 0.5325228 | 156 |  0.1865247 |  6.6343061 |   0.000 |
| gbb-pd   | 0.8033919 | 0.6122436 | 396 |  0.1911484 | 11.0976589 |   0.000 |
| gos-kdl  | 0.6468221 | 0.3716564 |  82 |  0.2751657 |  8.2388183 |   0.000 |
| gup-wat  | 0.4828080 | 0.3130238 |  49 |  0.1697842 |  3.9143476 |   0.000 |
| mwf-jm   | 0.4351447 | 0.2793821 |  36 |  0.1557626 |  2.4277642 |   0.010 |
| pjt-sw01 | 0.5721669 | 0.6071204 |  29 | -0.0349535 | -0.9462134 |   0.824 |
| wbp-jk   | 0.4681087 | 0.2669110 |  23 |  0.2011977 |  2.5630748 |   0.009 |
| wrl-mb   | 0.3790441 | 0.3519695 |  22 |  0.0270746 |  0.3317676 |   0.372 |
| wrm-pd   | 0.8434251 | 0.7133387 | 382 |  0.1300864 |  8.2400710 |   0.000 |

##### 20210225-Large-0FT\_transformer-L11 vs. wav2vec2-large-xlsr-53\_transformer-L11

``` r
t_test_func(
    greater_hyp = "20210225-Large-0FT_transformer-L11",
    less_hyp= "wav2vec2-large-xlsr-53_transformer-L11"
  ) %>%
  kable()
```

| dataset  |  gt\_mean |  lt\_mean | dof |       diff |    t.value | p.value |
|:---------|----------:|----------:|----:|-----------:|-----------:|--------:|
| eng-mav  | 0.8935692 | 0.7942569 |  99 |  0.0993123 |  3.9101914 |   0.000 |
| gbb-lg   | 0.7334673 | 0.7190475 | 156 |  0.0144198 |  0.5288214 |   0.299 |
| gbb-pd   | 0.8493772 | 0.8033919 | 396 |  0.0459853 |  3.7849636 |   0.000 |
| gos-kdl  | 0.7282060 | 0.6468221 |  82 |  0.0813839 |  2.9959783 |   0.002 |
| gup-wat  | 0.5610876 | 0.4828080 |  49 |  0.0782796 |  2.6758273 |   0.005 |
| mwf-jm   | 0.5153840 | 0.4351447 |  36 |  0.0802393 |  1.2949904 |   0.102 |
| pjt-sw01 | 0.6599793 | 0.5721669 |  29 |  0.0878124 |  2.1730335 |   0.019 |
| wbp-jk   | 0.4216062 | 0.4681087 |  23 | -0.0465025 | -0.6295555 |   0.732 |
| wrl-mb   | 0.5725867 | 0.3790441 |  22 |  0.1935426 |  3.4493787 |   0.001 |
| wrm-pd   | 0.8525557 | 0.8434251 | 382 |  0.0091306 |  0.7184611 |   0.236 |
