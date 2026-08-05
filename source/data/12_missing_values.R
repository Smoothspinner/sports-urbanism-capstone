# Adds a missing flag and a median-imputed column for each key predictor.
# Medians come from the training set only (no leakage). CPI excluded (mostly missing).

library(tidyverse)

add_flags_impute <- function(df, vars) {
  med <- df |> filter(set == "train") |>
    summarise(across(all_of(vars), ~ median(.x, na.rm = TRUE)))
  for (v in vars) {
    df[[paste0(v, "_missing")]] <- as.integer(is.na(df[[v]]))
    df[[paste0(v, "_imp")]]     <- coalesce(df[[v]], med[[v]])
  }
  df
}

num_vars <- c("log_capacity", "log_gdp", "log_city_pop", "log_distance", "venue_age",
              "years_since_event", "years_since_construction",
              "gdp_pct_rank", "gdp_z", "city_pop_pct_rank", "city_pop_z",
              "capacity_pct_rank", "capacity_z")

wc <- read_csv("data/processed/worldcup_model_split.csv", show_col_types = FALSE) |>
  add_flags_impute(num_vars)
ol <- read_csv("data/processed/olympic_model_split.csv", show_col_types = FALSE) |>
  add_flags_impute(num_vars)

# ---- Missing counts and post-imputation NA check ----
cat("World Cup, number missing per predictor:\n")
print(wc |> summarise(across(ends_with("_missing"), sum)))
cat("NAs left in WC imputed columns:", sum(is.na(select(wc, ends_with("_imp")))), "\n\n")
cat("Olympic, number missing per predictor:\n")
print(ol |> summarise(across(ends_with("_missing"), sum)))
cat("NAs left in Olympic imputed columns:", sum(is.na(select(ol, ends_with("_imp")))), "\n")

write_csv(wc, "data/processed/worldcup_model_split.csv")
write_csv(ol, "data/processed/olympic_model_split.csv")
cat("\nUpdated the split tables with missing flags + imputed columns\n")