# Author: MG
# Manual review of the Wikidata matches from 07_wikidata_olympic_pull.R.
# Doing it in R so there is no need to open the CSV in Excel

library(tidyverse)

f <- "data/external/wikidata_olympic_venues.csv"
dat <- read_csv(f, show_col_types = FALSE)

# ---- 1. The matched rows to eyeball (one line per venue) ----
review <- dat |>
  filter(!is.na(coords) | !is.na(capacity_wd) | !is.na(opened_year)) |>
  distinct(venue_name, host_city, .keep_all = TRUE) |>
  arrange(desc(capacity_wd))

cat("Matched venues to review:", nrow(review), "\n\n")
print(review |> select(venue_name, host_city, games_year, page_title,
                       capacity_wd, opened_year), n = 300)

# ---- 2. Wrong matches, found by eyeballing the printed table above ----
# SoFi Stadium: modern NFL stadium, matched by name search to the 1932 LA
# swimming venue, wrong sport and wrong era entirely.
# Tokyo Dome: a real, different Tokyo venue, matched instead of "Yokohama
# Baseball Stadium," the building actually used at the 2020 Games.
# Stadio Delle Alpi: Turin's demolished former stadium, matched instead of
# Stadio Olimpico Torino, the venue actually in use for the 2006 Games.
reject <- c(
  "SoFi Stadium",
  "Tokyo Dome",
  "Stadio Delle Alpi"
)

# ---- 3. Blank the facts for rejected pages and re-save ----
dat <- dat |>
  mutate(bad = !is.na(page_title) & page_title %in% reject,
         coords      = if_else(bad, NA_character_, coords),
         capacity_wd = if_else(bad, NA_real_, capacity_wd),
         opened_year = if_else(bad, NA_real_, opened_year),
         wikidata_id = if_else(bad, NA_character_, wikidata_id),
         page_title  = if_else(bad, NA_character_, page_title)) |>
  select(-bad)

write_csv(dat, f)
cat("\nRejected", length(reject), "match(es). Clean matches remaining:",
    sum(!is.na(dat$coords) | !is.na(dat$capacity_wd) | !is.na(dat$opened_year)),
    "\n")