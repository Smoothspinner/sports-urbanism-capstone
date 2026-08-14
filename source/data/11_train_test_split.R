# Author: MG
# Train/test split: grouped by venue (no venue in both sets) and stratified by
# outcome so both sets keep white elephants. A pure time-aware split left the
# World Cup test set with zero failures, so we split for evaluability instead.
# Ratio is 1/sqrt(number of predictors): 9 World Cup, 8 Olympic, as of this
# split. Recount and update if predictors are added or removed.

library(tidyverse)
set.seed(123)

nan_to_na <- function(x) if_else(is.nan(x), NA_real_, x)

# Capacity rank/z-score, scored against the TRAINING rows' distribution for
# that award year only, then applied to every row in the group. Stays here
# rather than moving to the join step like city population and GDP did,
# since there's no external "every stadium in the world" panel to rank
# against, only our own project's venues.
rank_within_train <- function(x, award_year, set) {
  d <- tibble(x = x, award_year = award_year, set = set, row = seq_along(x))
  train_ref <- d |> filter(set == "train") |>
    group_by(award_year) |>
    summarise(train_mean = mean(x, na.rm = TRUE),
              train_sd   = sd(x, na.rm = TRUE),
              train_vals = list(x[!is.na(x)]),
              .groups = "drop")
  d |> left_join(train_ref, by = "award_year") |>
    mutate(z   = nan_to_na((x - train_mean) / train_sd),
           pct = nan_to_na(map2_dbl(x, train_vals, function(v, ref) {
             if (is.na(v) || length(ref) == 0) return(NA_real_)
             mean(ref <= v)
           }))) |>
    arrange(row) |>
    select(z, pct)
}

# ---- World Cup ----
wc <- read_csv("data/processed/worldcup_model.csv", show_col_types = FALSE) |>
  filter(!is.na(white_elephant))
test_prop_wc <- round(1 / sqrt(9), 2)
wc_test_ids <- wc |> distinct(stadium_id, white_elephant) |>
  group_by(white_elephant) |> slice_sample(prop = test_prop_wc) |> pull(stadium_id)
wc <- wc |> mutate(set = if_else(stadium_id %in% wc_test_ids, "test", "train"))

wc_cap <- rank_within_train(wc$stadium_capacity, wc$award_year, wc$set)
wc$capacity_z <- wc_cap$z; wc$capacity_pct_rank <- wc_cap$pct

# ---- Olympic ----
ol <- read_csv("data/processed/olympic_model.csv", show_col_types = FALSE) |>
  filter(!is.na(white_elephant)) |> mutate(vid = paste(venue_name, host_city))
test_prop_ol <- round(1 / sqrt(8), 2)
ol_test_ids <- ol |> distinct(vid, white_elephant) |>
  group_by(white_elephant) |> slice_sample(prop = test_prop_ol) |> pull(vid)
ol <- ol |> mutate(set = if_else(vid %in% ol_test_ids, "test", "train"))

ol_cap <- rank_within_train(ol$capacity_wd, ol$award_year, ol$set)
ol$capacity_z <- ol_cap$z; ol$capacity_pct_rank <- ol_cap$pct

# ---- Check sizes and outcome balance ----
cat("WC train:test =", 1 - test_prop_wc, ":", test_prop_wc, "\n")
print(wc |> group_by(set) |> summarise(n = n(),
                                       white_elephant_rate = round(mean(white_elephant) * 100, 1)))
cat("\nOlympic train:test =", 1 - test_prop_ol, ":", test_prop_ol, "\n")
print(ol |> group_by(set) |> summarise(n = n(),
                                       white_elephant_rate = round(mean(white_elephant) * 100, 1)))

# ---- WC-only note: too few stadiums to score ----
# 4 genuine failures fall across 3 distinct stadiums (one hosted twice). The
# split keeps a stadium whole on one side, so the test set gets at most one of
# the 3, sometimes none. Reported as descriptive rather than fit as a scored
# classifier; see the M05 write-up for how this is handled.
cat("\nWorld Cup distinct failed stadiums:",
    n_distinct(wc$stadium_id[wc$white_elephant]), "\n")

# ---- Save ----
write_csv(wc, "data/processed/worldcup_model_split.csv")
write_csv(ol, "data/processed/olympic_model_split.csv")
cat("\nSaved worldcup_model_split.csv and olympic_model_split.csv\n")