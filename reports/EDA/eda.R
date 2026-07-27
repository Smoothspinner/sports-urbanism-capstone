library(tidyverse)
wc <- read_csv("data/processed/worldcup_stadiums_joined.csv")
ol <- read_csv("data/processed/olympic_venues_joined.csv")
ol <- ol |>
  mutate(
    status_clean = current_status |>
      str_replace_all("[\r\n]+", " ") |>   # remove the stray line breaks
      str_squish() |>
      str_to_lower(),
    status_group = case_when(
      str_starts(status_clean, "dismantled") ~ "temporary",
      str_starts(status_clean, "not in use") ~ "not in use",
      str_starts(status_clean, "in use")     ~ "in use"
    )
  )

ol |> count(status_group)

# Build the white_elephant target (temporary venues become NA and drop out)
ol <- ol |>
  mutate(white_elephant = case_when(
    status_group == "not in use" ~ TRUE,
    status_group == "in use"     ~ FALSE
  ))

wc <- wc |>
  mutate(white_elephant = case_when(
    current_status == "not in use" ~ TRUE,
    current_status == "in use"     ~ FALSE
  ))

# Class balance
wc |> count(white_elephant) |> mutate(pct = round(n / sum(n) * 100, 1))
ol |> filter(status_group != "temporary") |>
  count(white_elephant) |> mutate(pct = round(n / sum(n) * 100, 1))

# White-elephant rate by newly-built status
wc |> filter(!is.na(white_elephant)) |>
  group_by(newly_built) |>
  summarise(venues = n(),
            white_elephants = sum(white_elephant),
            rate_pct = round(mean(white_elephant) * 100, 1))

# White-elephant rate by design purpose
wc |> filter(!is.na(white_elephant)) |>
  group_by(design_purpose) |>
  summarise(venues = n(),
            white_elephants = sum(white_elephant),
            rate_pct = round(mean(white_elephant) * 100, 1)) |>
  arrange(desc(rate_pct))

# Clean the venue classification into tidy groups
ol <- ol |>
  mutate(
    class_clean = venue_classification |>
      str_replace_all("[\r\n]+", " ") |> str_squish() |> str_to_lower(),
    class_group = case_when(
      str_starts(class_clean, "existing")  ~ "Existing",
      str_starts(class_clean, "mixed")     ~ "Mixed",
      str_starts(class_clean, "temporary") ~ "Temporary",
      str_starts(class_clean, "new")       ~ "New"
    )
  )

ol |> count(class_group)

# White-elephant rate by classification (temporary venues have no target and drop out)
ol |> filter(!is.na(white_elephant)) |>
  group_by(class_group) |>
  summarise(venues = n(),
            white_elephants = sum(white_elephant),
            rate_pct = round(mean(white_elephant) * 100, 1)) |>
  arrange(desc(rate_pct))

# World Cup: median numeric features, white elephant vs in use
wc |> filter(!is.na(white_elephant)) |>
  group_by(white_elephant) |>
  summarise(n = n(),
            med_capacity = median(stadium_capacity, na.rm = TRUE),
            med_gdp      = round(median(gdp_per_capita, na.rm = TRUE)),
            med_city_pop = round(median(city_pop_thousands, na.rm = TRUE)))

# Olympic: median numeric features, white elephant vs in use
ol |> filter(!is.na(white_elephant)) |>
  group_by(white_elephant) |>
  summarise(n = n(),
            med_gdp      = round(median(gdp_per_capita, na.rm = TRUE)),
            med_city_pop = round(median(city_pop_thousands, na.rm = TRUE)))


# ================= REPORT FIGURES =================
col_we   <- "#C0392B"
col_mute <- "#B8C2CC"
col_blue <- "#2C6E9B"

theme_report <- theme_minimal(base_size = 13) +
  theme(
    plot.caption.position = "plot",
    plot.caption = element_text(color = "grey50", size = 8.5, hjust = 0,
                                margin = margin(t = 10)),
    axis.title.x = element_text(color = "grey30", margin = margin(t = 6)),
    axis.title.y = element_text(color = "grey30", margin = margin(r = 6)),
    axis.text    = element_text(color = "grey25", size = 10.5),
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(color = "grey90"),
    plot.margin  = margin(14, 18, 12, 14)
  )

# ---- Figure 1: unused rate by venue type (Olympic), Existing vs New ----
rate_by_class <- ol |>
  filter(!is.na(white_elephant), class_group %in% c("Existing", "New")) |>
  group_by(class_group) |>
  summarise(rate = mean(white_elephant) * 100, n = n(), .groups = "drop") |>
  mutate(x_lab = paste0(class_group, "\n(n = ", n, ")"),
         hi = class_group == "Existing")

p1 <- ggplot(rate_by_class, aes(reorder(x_lab, -rate), rate, fill = hi)) +
  geom_col(width = 0.55) +
  geom_text(aes(label = sprintf("%.1f%%", rate)),
            vjust = -0.5, fontface = "bold", size = 4.4, color = "grey15") +
  scale_fill_manual(values = c("TRUE" = col_we, "FALSE" = col_mute), guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.16))) +
  labs(x = "Venue type", y = "Venues left unused (%)",
       caption = "Olympic venues, 1896-2022. 'Existing' = already there before the Games; 'New' = built for the Games. Temporary excluded.") +
  theme_report
ggsave("reports/EDA/fig_olympic_rate_by_class.png", p1,
       width = 7.5, height = 4.6, dpi = 300, bg = "white")

# ---- Figure 2: how rare unused venues are (both events) ----
balance <- bind_rows(
  wc |> filter(!is.na(white_elephant)) |>
    summarise(event = "World Cup", rate = mean(white_elephant)*100,
              we = sum(white_elephant), n = n()),
  ol |> filter(!is.na(white_elephant)) |>
    summarise(event = "Olympics", rate = mean(white_elephant)*100,
              we = sum(white_elephant), n = n())
)

p2 <- ggplot(balance, aes(reorder(event, -rate), rate)) +
  geom_col(width = 0.55, fill = col_we) +
  geom_text(aes(label = sprintf("%.1f%%", rate)),
            vjust = -1.5, fontface = "bold", size = 4.6, color = "grey15") +
  geom_text(aes(label = paste0(we, " of ", n)),
            vjust = -0.5, size = 3.3, color = "grey45") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.22))) +
  labs(x = "Event", y = "Venues left unused (%)",
       caption = "World Cup venues 1930-2022; Olympic venues 1896-2022. Temporary venues excluded.") +
  theme_report
ggsave("reports/EDA/fig_class_balance.png", p2,
       width = 6.8, height = 4.6, dpi = 300, bg = "white")

# ---- Figure 3: unused rate over time (Olympic), one point per Games ----
rate_by_games <- ol |>
  filter(!is.na(white_elephant)) |>
  group_by(games_year) |>
  summarise(rate = mean(white_elephant) * 100, n = n(), .groups = "drop")

p3 <- ggplot(rate_by_games, aes(games_year, rate)) +
  geom_smooth(method = "lm", se = FALSE, color = col_we, linewidth = 1) +
  geom_point(aes(size = n), color = col_blue, alpha = 0.7) +
  scale_size_continuous(range = c(1.5, 5), name = "Venues per Games") +
  scale_y_continuous(limits = c(0, NA)) +
  labs(x = "Year the Games were held", y = "Venues left unused (%)",
       caption = "Each dot is one Olympic Games, sized by how many venues it had. Line = linear trend. Temporary venues excluded.") +
  theme_report
ggsave("reports/EDA/fig_olympic_rate_over_time.png", p3,
       width = 8, height = 4.6, dpi = 300, bg = "white")

# ---- Figure 4: collinearity among numeric variables (World Cup), lower triangle ----
wc_num <- wc |>
  transmute(`Award year`     = award_year,
            `Opened year`     = opened_year,
            `Capacity`        = stadium_capacity,
            `GDP per capita`  = gdp_per_capita,
            `City pop (000s)` = city_pop_thousands)

cor_mat <- cor(wc_num, use = "pairwise.complete.obs", method = "spearman")
vars <- colnames(cor_mat)
cor_mat[upper.tri(cor_mat, diag = TRUE)] <- NA          

cor_df <- as.data.frame(as.table(cor_mat))
names(cor_df) <- c("v1", "v2", "corr")
cor_df <- cor_df |> filter(!is.na(corr))
cor_df$v1 <- factor(cor_df$v1, levels = vars)
cor_df$v2 <- factor(cor_df$v2, levels = rev(vars))

p4 <- ggplot(cor_df, aes(v1, v2, fill = corr)) +
  geom_tile(color = "white", linewidth = 0.6) +
  geom_text(aes(label = sprintf("%.2f", corr)), size = 3.8, color = "grey15") +
  scale_fill_gradient2(low = "#2C6E9B", mid = "white", high = "#C0392B",
                       midpoint = 0, limits = c(-1, 1), name = "Spearman r") +
  labs(x = NULL, y = NULL,
       caption = "World Cup numeric variables. Spearman correlations, pairwise complete. CPI omitted (96% missing).") +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1),
        panel.grid = element_blank(),
        plot.caption = element_text(hjust = 0, color = "grey50", size = 8.5))
ggsave("reports/EDA/fig_collinearity_wc.png", p4,
       width = 6.8, height = 5.2, dpi = 300, bg = "white")

# ---- Figure 5: stadium capacity by outcome (World Cup), distinct venues ----
wc_caps <- wc |>
  filter(!is.na(white_elephant)) |>
  distinct(stadium_id, .keep_all = TRUE) |>
  mutate(outcome = if_else(white_elephant, "Left unused", "In use"))

cnts <- wc_caps |> count(outcome)
lab_map <- setNames(paste0(cnts$outcome, "\n(n = ", cnts$n, ")"), cnts$outcome)
wc_caps <- wc_caps |> mutate(outcome_lab = lab_map[outcome])

p5 <- ggplot(wc_caps, aes(outcome_lab, stadium_capacity)) +
  geom_boxplot(width = 0.5, fill = "#B8C2CC", outlier.alpha = 0.5) +
  geom_text(data = wc_caps |> filter(stadium_capacity >= 190000),
            aes(label = "Maracanã (200,000)"),
            nudge_x = 0.42, size = 3.1, color = "grey30", fontface = "italic") +
  scale_y_continuous(labels = scales::comma) +
  labs(x = NULL, y = "Stadium capacity (seats)",
       caption = "World Cup stadiums, distinct venues only (repeats across tournaments removed). Box = middle 50%; line = median.") +
  theme_report
ggsave("reports/EDA/fig_capacity_by_outcome.png", p5,
       width = 6.5, height = 4.6, dpi = 300, bg = "white")

# ================= TABLE 1: DESCRIPTIVE STATISTICS =================
skewness <- function(x) {
  x <- x[!is.na(x)]; if (length(x) < 3) return(NA)
  m <- mean(x); s <- sd(x); mean((x - m)^3) / s^3
}

summarise_cont <- function(df, vars, dataset) {
  df |> select(all_of(vars)) |>
    pivot_longer(everything(), names_to = "variable", values_to = "value") |>
    group_by(variable) |>
    summarise(dataset = dataset,
              n      = sum(!is.na(value)),
              mean   = round(mean(value, na.rm = TRUE), 1),
              sd     = round(sd(value, na.rm = TRUE), 1),
              median = round(median(value, na.rm = TRUE), 1),
              min    = round(min(value, na.rm = TRUE), 1),
              max    = round(max(value, na.rm = TRUE), 1),
              skew   = round(skewness(value), 2), .groups = "drop") |>
    relocate(dataset)
}

summarise_cat <- function(df, vars, dataset) {
  df |> mutate(across(all_of(vars), as.character)) |>
    select(all_of(vars)) |>
    pivot_longer(everything(), names_to = "variable", values_to = "level") |>
    filter(!is.na(level)) |>
    count(variable, level) |>
    group_by(variable) |> mutate(percent = round(n / sum(n) * 100, 1)) |> ungroup() |>
    mutate(dataset = dataset) |> relocate(dataset)
}

cont_tbl <- bind_rows(
  summarise_cont(wc, c("stadium_capacity","gdp_per_capita","cpi_score",
                       "city_pop_thousands","award_year","opened_year"), "World Cup"),
  summarise_cont(ol, c("gdp_per_capita","cpi_score","city_pop_thousands",
                       "games_year","award_year"), "Olympics")
)

cat_tbl <- bind_rows(
  summarise_cat(wc, c("newly_built","design_purpose"), "World Cup"),
  summarise_cat(ol, c("class_group","status_group"), "Olympics")
)

print(cont_tbl, n = 30)
print(cat_tbl, n = 40)
write_csv(cont_tbl, "reports/EDA/table1_descriptive_continuous.csv")
write_csv(cat_tbl,  "reports/EDA/table1_descriptive_categorical.csv")

# ================= TABLE 2: OUTCOME STRATIFIED BY PREDICTOR =================
# 2a: white-elephant rate by each categorical predictor
rate_by_cat <- function(df, vars, dataset) {
  df |> filter(!is.na(white_elephant)) |>
    select(all_of(vars), white_elephant) |>
    pivot_longer(all_of(vars), names_to = "variable", values_to = "level") |>
    filter(!is.na(level)) |>
    group_by(variable, level) |>
    summarise(n = n(),
              we_rate_pct = round(mean(white_elephant) * 100, 1),
              .groups = "drop") |>
    mutate(dataset = dataset) |> relocate(dataset)
}

tbl2_cat <- bind_rows(
  rate_by_cat(wc, c("newly_built", "design_purpose"), "World Cup"),
  rate_by_cat(ol, c("class_group"), "Olympics")
)

# 2b: median of each continuous predictor by outcome
med_by_outcome <- function(df, vars, dataset) {
  df |> filter(!is.na(white_elephant)) |>
    select(all_of(vars), white_elephant) |>
    pivot_longer(all_of(vars), names_to = "variable", values_to = "value") |>
    mutate(outcome = if_else(white_elephant, "Left_unused", "In_use")) |>
    group_by(variable, outcome) |>
    summarise(median = round(median(value, na.rm = TRUE), 1), .groups = "drop") |>
    pivot_wider(names_from = outcome, values_from = median) |>
    mutate(dataset = dataset) |> relocate(dataset)
}

tbl2_cont <- bind_rows(
  med_by_outcome(wc, c("stadium_capacity","gdp_per_capita","city_pop_thousands"), "World Cup"),
  med_by_outcome(ol, c("gdp_per_capita","city_pop_thousands"), "Olympics")
)

print(tbl2_cat, n = 30)
print(tbl2_cont, n = 30)
write_csv(tbl2_cat,  "reports/EDA/table2_rate_by_category.csv")
write_csv(tbl2_cont, "reports/EDA/table2_median_by_outcome.csv")