# Olympic-side twin of 04_join_country_data.R.
# Attaches country income (GDP), corruption (CPI), and host-city population to
# Brian's Olympic venue table (VenueReportsV2.xlsx, "At A Glance" sheet), joined
# at each Games' AWARD year. Uses 05_olympic_games_lookup.R's output for the
# award year + host country of each edition.
#
# Same rules as the World Cup side:
#  - GDP and CPI join on (country code, award year).
#  - City population uses the CLOSEST available UN year, and the gap is recorded
#    in city_pop_year_gap so nothing is a hidden guess.
#  - CPI only exists from 2012, so only Games AWARDED in 2012+ (Tokyo 2020,
#    Beijing 2022) get a corruption score; everything else is GDP-only.
#
# Dead-country handling (per team decision):
#  - West Germany -> Germany (clean continuation).
#  - Soviet Union (Moscow 1980) and Yugoslavia (Sarajevo 1984) -> NA. Those
#    venues carry no GDP/CPI/population. Stated limitation, not a bug.

library(tidyverse)
library(readxl)
library(countrycode)
library(stringi)

# ---- 0. Read Brian's Olympic venue table ----
# Keep the raw workbook untouched in data/raw/; we read the "At A Glance" sheet
# and keep the first six columns (the rest are blank / bookkeeping).
venues_raw <- read_excel("data/raw/VenueReportsV2.xlsx", sheet = "At A Glance")

venues <- venues_raw[, 1:6]
names(venues) <- c("venue_name", "venue_classification", "use_at_games",
                   "current_status", "games_year", "host_city")

venues <- venues |>
  mutate(games_year = as.integer(as.character(games_year)),
         host_city  = str_squish(host_city),
         row_id     = row_number()) |>
  filter(!is.na(venue_name))

# ---- 1. Attach award year + host country from the Games lookup ----
games <- read_csv("data/external/olympic_games_lookup.csv",
                  show_col_types = FALSE) |>
  mutate(games_year = as.integer(games_year),
         host_city  = str_squish(host_city))

venues <- venues |>
  left_join(games, by = c("games_year", "host_city"))

# Any venue whose (year, city) didn't match the lookup is a problem - report it.
unmatched_games <- venues |> filter(is.na(award_year)) |>
  distinct(games_year, host_city)
if (nrow(unmatched_games) > 0) {
  cat("WARNING - venues with no Games-lookup match:\n"); print(unmatched_games)
}

# ---- 2. Standard 3-letter country code (with dead-country handling) ----
venues <- venues |>
  mutate(iso3c = countrycode(
    host_country, "country.name", "iso3c",
    custom_match = c("West Germany" = "DEU",
                     "Soviet Union" = NA_character_,
                     "Yugoslavia"   = NA_character_)))

# ---- 3. GDP per capita at the award year ----
# NOTE: the World Bank file contains regional aggregates with a BLANK country
# code (read as NA). Our two dead-country editions (Moscow 1980, Sarajevo 1984)
# also have iso3c = NA, and R's join treats NA as matching NA - which would give
# them false GDP values and duplicate their rows. Dropping NA-code reference
# rows keeps dead countries as clean NAs.
gdp <- read_csv("data/processed/worldbank_gdp_per_capita_long.csv",
                show_col_types = FALSE)
venues <- venues |>
  left_join(gdp |> filter(!is.na(iso3c)) |> select(iso3c, year, gdp_per_capita),
            by = c("iso3c", "award_year" = "year"))

# ---- 4. Corruption score at the award year (2012+ only) ----
cpi <- read_csv("data/processed/cpi_2012_2025_long.csv",
                show_col_types = FALSE)
venues <- venues |>
  left_join(cpi |> filter(!is.na(iso3c)) |> select(iso3c, year, cpi_score),
            by = c("iso3c", "award_year" = "year"))

# ---- 5. Host-city population, closest available UN year ----
un <- read_csv("data/processed/un_city_population_long.csv",
               show_col_types = FALSE)

clean_key <- function(x) {
  x |>
    str_replace_all(" ", " ") |>
    stri_trans_general("Latin-ASCII") |>
    str_to_lower() |>
    str_squish()
}

# Winter-Games / IOC spellings. The UN file uses English names, so unlike the
# World Cup side only two host cities need remapping. Everything not listed here
# and not in the UN file (small Winter towns: Chamonix, St. Moritz, Lake Placid,
# Garmisch-Partenkirchen, Cortina d'Ampezzo, Squaw Valley, Albertville,
# Lillehammer, PyeongChang) simply has no UN entry -> NA population (limitation).
alias <- tribble(
  ~from,                   ~to,
  "melbourne / stockholm", "melbourne",   # 1956 Games awarded to Melbourne
  "torino",                "turin"        # UN lists Turin, not Torino
)

un_keys <- un |>
  mutate(primary = clean_key(str_remove(city, "\\s*\\(.*\\)$")),
         alt     = if_else(str_detect(city, "\\("),
                           clean_key(str_extract(city, "(?<=\\().*(?=\\))")),
                           NA_character_)) |>
  pivot_longer(c(primary, alt), values_to = "join_city") |>
  filter(!is.na(join_city)) |>
  group_by(iso3c, join_city, year) |>
  summarise(city_pop_thousands = max(pop_thousands), .groups = "drop")

# For each venue, find the UN row for its host city closest to the award year.
nearest <- venues |>
  mutate(join_city = clean_key(host_city)) |>
  left_join(alias, by = c("join_city" = "from")) |>
  mutate(join_city = coalesce(to, join_city)) |>
  select(row_id, iso3c, join_city, award_year) |>
  filter(!is.na(iso3c), !is.na(award_year)) |>
  inner_join(un_keys, by = c("iso3c", "join_city"),
             relationship = "many-to-many") |>
  mutate(city_pop_year_gap = abs(year - award_year)) |>
  group_by(row_id) |>
  slice_min(city_pop_year_gap, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(row_id, city_pop_thousands, city_pop_year_used = year,
         city_pop_year_gap)

venues <- venues |> left_join(nearest, by = "row_id") |> select(-row_id)

write_csv(venues, "data/processed/olympic_venues_joined.csv")

# ---- 6. Report ----
cat("Venues:", nrow(venues), "\n")
cat("GDP matched:", sum(!is.na(venues$gdp_per_capita)), "of", nrow(venues), "\n")
cat("CPI matched:", sum(!is.na(venues$cpi_score)), "of", nrow(venues),
    "(expected: only Games awarded 2012+)\n")
cat("City pop matched:", sum(!is.na(venues$city_pop_thousands)),
    "of", nrow(venues), "\n")
cat("Year gaps used - median:", median(venues$city_pop_year_gap, na.rm = TRUE),
    "| max:", max(venues$city_pop_year_gap, na.rm = TRUE), "\n\n")
cat("Host cities with no UN population entry (expected NAs):\n")
venues |>
  filter(is.na(city_pop_thousands)) |>
  distinct(games_year, host_city, host_country) |>
  arrange(games_year) |>
  print(n = 40)
