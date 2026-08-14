# Author: MG
# Reproduces Table 1: tests whether each imputed predictor's missing-value
# flag is itself related to the outcome, using Fisher's exact test. If it
# were, the imputed values would reflect data availability rather than the
# venue. 
library(tidyverse)

ol <- read_csv("data/processed/olympic_model_split.csv", show_col_types = FALSE) |>
  filter(set == "train")

missingness_test <- function(flag_col, label) {
  tab <- table(ol[[flag_col]], ol$white_elephant)
  test <- fisher.test(tab)
  pct_missing <- round(100 * mean(ol[[flag_col]] == 1), 0)
  cat(sprintf("%-22s missing %2d%%  Fisher's p = %.3f\n",
              label, pct_missing, test$p.value))
}

cat("Table 1: missingness tested against the outcome for every predictor we impute\n\n")
missingness_test("log_capacity_missing", "Capacity")
missingness_test("venue_age_missing", "Venue age")
missingness_test("gdp_pct_rank_missing", "GDP percentile rank")
missingness_test("city_pop_pct_rank_missing", "Host city population")