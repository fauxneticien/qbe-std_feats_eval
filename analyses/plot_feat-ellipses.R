library(tidyverse)
library(ggthemes)
library(ggrepel)

library(here)

make_plot_df <- function(T_feats_csv, model_name) {
  
  xlsr_feats <- read_csv(T_feats_csv) %>%
    filter(text %in% c("t", "th", "rt", "ty", "n", "nh", "rn", "ny"))
  
  xlsr_dists <- xlsr_feats %>%
    select(-text, -file) %>%
    dist()
  
  xlsr_dists[which(is.na(xlsr_dists))] <- 1
  
  xlsr_fit <- cmdscale(xlsr_dists, eig=TRUE, k=2)
  
  tibble(
      text = xlsr_feats$text,
      x    = xlsr_fit$points[,1],
      y    = xlsr_fit$points[,2]
    ) %>%
    mutate(
      `Place of articulation` = case_when(
        text %in% c("p", "m") ~ "Labial",
        text %in% c("t", "n") ~ "Alveolar",
        text %in% c("th", "nh") ~ "Dental",
        text %in% c("rt", "rn") ~ "Retroflex",
        text %in% c("ty", "ny") ~ "Palatal",
        text %in% c("k", "ng") ~ "Velar"
      ) %>% 
        factor(levels = c("Labial", "Alveolar", "Dental", "Retroflex", "Palatal", "Velar")),
      `Manner of articulation` = ifelse(str_detect(text, "(p|t|k)"), "Plosive", "Nasal"),
      text = case_when(
        text == "ng" ~ "1",
        text == "ny" ~ "2",
        text == "rt" ~ "3",
        text == "ty" ~ "4",
        text == "th" ~ "5",
        text == "nh" ~ "6",
        text == "rn" ~ "7",
        TRUE ~ text
      ),
      Model = model_name
    )
  
}

ellipses_plot_df <- bind_rows(
  make_plot_df(here("analyses/data/Kaytetye-consonants_w2v2-large_T11-feats.csv"), "LS960-T11"),
  make_plot_df(here("analyses/data/Kaytetye-consonants_w2v2-xlsr_T11-feats.csv"), "XLSR53-T11")
)

ellipses_plot_means <- plot_df %>% 
  group_by(Model, `Place of articulation`, `Manner of articulation`, text) %>%
  summarise(x = mean(x), y = mean(y)) %>%
  ungroup %>%
  mutate(
         # n, t, nh, th, rn, rt, ny, ty, n, t, nh, th, rn, rt, ny, ty 
    vj = c(1,    0.5,  -0.75,  0,  -0.5,  -0.5, 0, 1, -1,   0,   0, -1, 0, 2, 0, 0),
    hj = c(-0.5, -1,   -1.14,  2,   1,    0.5,  0, 0, 1, -1.5, -1,  0, 0, 0, 0, 0)
  )

ellipses_plot_df %>%
  ggplot(aes(x = y, y = x, group = text)) +
  stat_ellipse(aes(lty = `Manner of articulation`, color = `Place of articulation`)) +
  geom_point(data = ellipses_plot_means, aes(color = `Place of articulation`)) +
  geom_label_repel(
    data = ellipses_plot_means,
    aes(label = text, fill = `Place of articulation`, vjust = vj, hjust = hj),
    force = 3
  ) +
  facet_wrap(~ Model) +
  scale_fill_manual(values = c("#1b9e77", "#d95f02", "#7570b3", "#e41a1c", "#e6ab02", "#e7298a")) +
  scale_color_manual(values = c("#1b9e77", "#d95f02", "#7570b3", "#e41a1c", "#e6ab02", "#e7298a")) +
  theme_bw(base_size = 11) +
  xlab("MDS Dimension 1") +
  ylab("MDS Dimension 2")
