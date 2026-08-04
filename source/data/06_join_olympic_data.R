# Olympic twin of 04_join_country_data.R: attaches GDP, corruption (CPI), and
# host-city population to the Olympic venue table at each Games' award year.
# Dead countries (USSR, Yugoslavia) carry no country data by design.

library(tidyverse)
library(readxl)
library(countrycode)
library(stringi)

# ---- Read the Olympic venue table (first six columns of "At A Glance") ----
venues_raw <- read_excel("data/raw/VenueReportsV3.xlsx", sheet = "At A Glance")
venues <- venues_raw[, 1:6]
names(venues) <- c("venue_name", "venue_classification", "use_at_games",
                   "current_status", "games_year", "host_city")
venues <- venues |>
  mutate(games_year = as.integer(as.character(games_year)),
         host_city  = str_squish(host_city),
         row_id     = row_number()) |>
  filter(!is.na(venue_name))

# ---- Award year + host country from the Games lookup ----
games <- read_csv("data/external/olympic_games_lookup.csv", show_col_types = FALSE) |>
  mutate(games_year = as.integer(games_year), host_city = str_squish(host_city))
venues <- venues |> left_join(games, by = c("games_year", "host_city"))

unmatched_games <- venues |> filter(is.na(award_year)) |> distinct(games_year, host_city)
if (nrow(unmatched_games) > 0) { cat("WARNING - venues with no lookup match:\n"); print(unmatched_games) }

# ---- Country code; West Germany -> Germany, USSR/Yugoslavia -> NA ----
venues <- venues |>
  mutate(iso3c = countrycode(host_country, "country.name", "iso3c",
                             custom_match = c("West Germany" = "DEU",
                                              "Soviet Union" = NA_character_,
                                              "Yugoslavia"   = NA_character_)))

# ---- GDP at award year (drop blank-code aggregates so NA never matches NA) ----
gdp <- read_csv("data/processed/worldbank_gdp_per_capita_long.csv", show_col_types = FALSE)
venues <- venues |>
  left_join(gdp |> filter(!is.na(iso3c)) |> select(iso3c, year, gdp_per_capita),
            by = c("iso3c", "award_year" = "year"))

# ---- CPI at award year (2012+ only) ----
cpi <- read_csv("data/processed/cpi_2012_2025_long.csv", show_col_types = FALSE)
venues <- venues |>
  left_join(cpi |> filter(!is.na(iso3c)) |> select(iso3c, year, cpi_score),
            by = c("iso3c", "award_year" = "year"))

# ---- Host-city population, nearest available UN year ----
un <- read_csv("data/processed/un_city_population_long.csv", show_col_types = FALSE)

clean_key <- function(x) {
  x |> str_replace_all(" ", " ") |> stri_trans_general("Latin-ASCII") |>
    str_to_lower() |> str_squish()
}

# Winter/IOC city spellings; UN uses English names so only two need remapping.
alias <- tribble(
  ~from,                   ~to,
  "melbourne / stockholm", "melbourne",
  "torino",                "turin"
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

# Nearest UN year to each venue's award year.
nearest <- venues |>
  mutate(join_city = clean_key(host_city)) |>
  left_join(alias, by = c("join_city" = "from")) |>
  mutate(join_city = coalesce(to, join_city)) |>
  select(row_id, iso3c, join_city, award_year) |>
  filter(!is.na(iso3c), !is.na(award_year)) |>
  inner_join(un_keys, by = c("iso3c", "join_city"), relationship = "many-to-many") |>
  mutate(city_pop_year_gap = abs(year - award_year)) |>
  group_by(row_id) |>
  slice_min(city_pop_year_gap, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(row_id, city_pop_thousands, city_pop_year_used = year, city_pop_year_gap)

venues <- venues |> left_join(nearest, by = "row_id") |> select(-row_id)
write_csv(venues, "data/processed/olympic_venues_joined.csv")

# ---- Report ----
cat("Venues:", nrow(venues), "\n")
cat("GDP matched:", sum(!is.na(venues$gdp_per_capita)), "of", nrow(venues), "\n")
cat("CPI matched:", sum(!is.na(venues$cpi_score)), "of", nrow(venues), "\n")
cat("City pop matched:", sum(!is.na(venues$city_pop_thousands)), "of", nrow(venues), "\n")
cat("Year gaps - median:", median(venues$city_pop_year_gap, na.rm = TRUE),
    "| max:", max(venues$city_pop_year_gap, na.rm = TRUE), "\n\n")
cat("Host cities with no UN population entry:\n")
venues |> filter(is.na(city_pop_thousands)) |>
  distinct(games_year, host_city, host_country) |> arrange(games_year) |> print(n = 40)
