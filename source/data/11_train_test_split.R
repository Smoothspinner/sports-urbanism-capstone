# Train/test split: grouped by venue (no venue in both sets) and stratified by
# outcome so both sets keep white elephants. A pure time-aware split left the
# World Cup test set with zero failures, so we split for evaluability instead.
# Ratio from Katie's calcSplitRatio (test = 1/sqrt(p)).

library(tidyverse)
set.seed(123)

# ---- World Cup ----
wc <- read_csv("data/processed/worldcup_model.csv", show_col_types = FALSE) |>
  filter(!is.na(white_elephant))
test_prop_wc <- round(1 / sqrt(9), 2)
wc_test_ids <- wc |> distinct(stadium_id, white_elephant) |>
  group_by(white_elephant) |> slice_sample(prop = test_prop_wc) |> pull(stadium_id)
wc <- wc |> mutate(set = if_else(stadium_id %in% wc_test_ids, "test", "train"))

# ---- Olympic ----
ol <- read_csv("data/processed/olympic_model.csv", show_col_types = FALSE) |>
  filter(!is.na(white_elephant)) |> mutate(vid = paste(venue_name, host_city))
test_prop_ol <- round(1 / sqrt(8), 2)
ol_test_ids <- ol |> distinct(vid, white_elephant) |>
  group_by(white_elephant) |> slice_sample(prop = test_prop_ol) |> pull(vid)
ol <- ol |> mutate(set = if_else(vid %in% ol_test_ids, "test", "train"))

# ---- Check sizes and outcome balance ----
cat("WC train:test =", 1 - test_prop_wc, ":", test_prop_wc, "\n")
print(wc |> group_by(set) |> summarise(n = n(),
                                       white_elephant_rate = round(mean(white_elephant) * 100, 1)))
cat("\nOlympic train:test =", 1 - test_prop_ol, ":", test_prop_ol, "\n")
print(ol |> group_by(set) |> summarise(n = n(),
                                       white_elephant_rate = round(mean(white_elephant) * 100, 1)))

# ---- Save ----
write_csv(wc, "data/processed/worldcup_model_split.csv")
write_csv(ol, "data/processed/olympic_model_split.csv")
cat("\nSaved worldcup_model_split.csv and olympic_model_split.csv\n")
