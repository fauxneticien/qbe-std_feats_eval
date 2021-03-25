plot_mtwvs <- function(mtwv_df, wav2vec_checkpoint_name = "wav2vec 2.0 Large (LibriSpeech 960h)") {

  plot_df <- mtwv_df %>%
    rename(
      Dataset  = dataset,
      Features = features,
      MTWV     = mtwv
    ) %>%
    mutate(
      Features = case_when(
        Features %in% c("mfcc", "bnf")    ~ str_to_upper(Features),
        str_detect(Features, "encoder")   ~ "E",
        str_detect(Features, "quantizer") ~ "Q",
        TRUE ~ str_extract(Features, "-L\\d+") %>% str_replace("-L", "T")
      ),
      Model = ifelse(
        Features %in% c("MFCC", "BNF"),
        Features,
        wav2vec_checkpoint_name
      ) %>%
        factor(levels = c("MFCC", "BNF", wav2vec_checkpoint_name)),
      # Legend ordering
      Dataset = factor(
        Dataset,
        levels = c("eng-mav", "gos-kdl", "gbb-pd", "wrm-pd", "gbb-lg",
                   "pjt-sw01", "wrl-mb", "gup-wat", "mwf-jm", "wbp-jk")
      ),
      Features = factor(
        Features,
        levels = c("MFCC", "BNF", "E", "Q",
                   paste("T", str_pad(1:24, 2, "left", "0"), sep =""))
      )
    )
  
  plot_top_ranked <- plot_df %>% 
    group_by(Dataset) %>%
    slice_max(order_by = MTWV, n = 1)
  
  plot_df %>% 
    ggplot(aes(x = Features, y = MTWV, group = Dataset)) +
    geom_line(aes(linetype = Dataset), color = "grey", show.legend = FALSE) +
    geom_point(aes(shape = Dataset), size = 3) +
    geom_point(
      aes(shape = Dataset),
      size = 3.5,
      stroke = 1,
      color = "#e41a1c",
      data = plot_top_ranked,
      show.legend = FALSE
      # position = "jitter"
    ) +
    facet_grid(~ Model, space = "free_x", scales = "free_x") +
    scale_y_continuous(limits = c(0, 1)) +
    theme(legend.position="bottom") +
    theme_base(base_size = 14) +
    theme(
      rect = element_blank(),
      panel.grid.major = element_line(colour = "grey"),
      legend.position="bottom",
      legend.margin=margin(0,0,0,0),
      legend.box.margin=margin(-5,-5,-5,-5)
    ) +
    scale_shape_manual(values = c(
      18, # eng-mav
      19, # nld-gng
      2,  # gbb-pd
      6,  # wrm-pd
      3,  # wrl-mb
      4,  # gup-wat
      8,  # pjt-sw01
      1,  # wbp-jk
      0,  # mwf-jm
      5   # gbb-lg
    )) +
    guides(
      colour = guide_legend(show = FALSE),
      shape = guide_legend(override.aes = list(size = 4), nrow = 1)
    )

}