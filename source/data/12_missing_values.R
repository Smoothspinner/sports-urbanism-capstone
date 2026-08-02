# Missing-value handling on the split tables. For each key predictor: add a 0/1
# missing flag, then impute NAs with the TRAINING median (train only, applied to
# both sets, so no leakage). Flags keep the "was it measured" signal. CPI is
# dropped as a predictor (94-96% missing) rather than imputed.

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

num_vars <- c("log_capacity", "log_gdp", "log_city_pop", "log_distance", "venue_age")

wc <- read_csv("data/processed/worldcup_model_split.csv", show_col_types = FALSE) |>
  add_flags_impute(num_vars)
ol <- read_csv("data/processed/olympic_model_split.csv", show_col_types = FALSE) |>
  add_flags_impute(num_vars)

# ---- Check: flags count the gaps, and no NA remains in the imputed columns ----
cat("World Cup, number missing per predictor:\n")
print(wc |> summarise(across(ends_with("_missing"), sum)))
cat("NAs left in WC imputed columns:", sum(is.na(select(wc, ends_with("_imp")))), "\n\n")
cat("Olympic, number missing per predictor:\n")
print(ol |> summarise(across(ends_with("_missing"), sum)))
cat("NAs left in Olympic imputed columns:", sum(is.na(select(ol, ends_with("_imp")))), "\n")

write_csv(wc, "data/processed/worldcup_model_split.csv")
write_csv(ol, "data/processed/olympic_model_split.csv")
cat("\nUpdated the split tables with missing flags + imputed columns\n")
