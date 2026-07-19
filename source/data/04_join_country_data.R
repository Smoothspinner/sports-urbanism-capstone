# Attaches country income (GDP), corruption (CPI), and host-city population
# to Jay's stadium table at the award year. City population uses the closest
# available UN year (recorded in city_pop_year_gap) because UN coverage for
# many cities only starts in 2000. 

library(tidyverse)
library(countrycode)
library(stringi)

venues <- read_csv("data/processed/worldcup_stadiums_by_tournament.csv",
                   show_col_types = FALSE)
gdp <- read_csv("data/processed/worldbank_gdp_per_capita_long.csv",
                show_col_types = FALSE)
cpi <- read_csv("data/processed/cpi_2012_2025_long.csv",
                show_col_types = FALSE)
un  <- read_csv("data/processed/un_city_population_long.csv",
                show_col_types = FALSE)

# ---- 1. Standard 3-letter country code ----
venues <- venues |>
  mutate(iso3c = countrycode(country_name, "country.name", "iso3c",
                             custom_match = c("England" = "GBR")),
         row_id = row_number())

# ---- 2. GDP per capita at the award year ----
venues <- venues |>
  left_join(gdp |> select(iso3c, year, gdp_per_capita),
            by = c("iso3c", "award_year" = "year"))

# ---- 3. Corruption score at the award year (2012+ only) ----
venues <- venues |>
  left_join(cpi |> select(iso3c, year, cpi_score),
            by = c("iso3c", "award_year" = "year"))

# ---- 4. Host-city population, closest available year ----
clean_key <- function(x) {
  x |>
    str_replace_all("\u00a0", " ") |>
    stri_trans_general("Latin-ASCII") |>
    str_to_lower() |>
    str_squish()
}

alias <- tribble(
  ~from,             ~to,
  "san fransisco",   "san francisco",
  "east rutherford", "new york city",
  "foxborough",      "boston",
  "carson",          "los angeles",
  "pasadena",        "los angeles",
  "pontiac",         "detroit",
  "saint-denis",     "paris",
  "nezahualcoyotl",  "ciudad de mexico",
  "solna",           "stockholm",
  "mexico city",     "ciudad de mexico",
  "rome",            "roma",
  "moscow",          "moskva",
  "doha",            "ad-dawhah",
  # cities the UN counts inside a larger urban area
  "yokohama",        "tokyo",
  "saitama",         "tokyo",
  "kobe",            "osaka",
  "ibaraki",         "osaka",
  "miyagi",          "sendai",
  "incheon",         "seoul",
  "suwon",           "seoul",
  "foshan",          "guangzhou",
  "jiangmen",        "guangzhou",
  "bochum",          "essen",
  "gelsenkirchen",   "essen",
  "leverkusen",      "cologne",
  "al rayyan",       "ad-dawhah",
  "lusail",          "ad-dawhah",
  "vina del mar",    "valparaiso",
  "antibes",         "nice",
  # renames and local spellings
  "port elizabeth",  "gqeberha",
  "nelspruit",       "mbombela",
  "oviedo",          "oviedo / uvieu",
  "elche",           "elx / elche",
  "san jose",        "san francisco",
  "stanford",        "san francisco"
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

# For each venue, find the UN row for its city closest to the award year.
nearest <- venues |>
  mutate(join_city = clean_key(city_name)) |>
  left_join(alias, by = c("join_city" = "from")) |>
  mutate(join_city = coalesce(to, join_city)) |>
  select(row_id, iso3c, join_city, award_year) |>
  inner_join(un_keys, by = c("iso3c", "join_city"),
             relationship = "many-to-many") |>
  mutate(city_pop_year_gap = abs(year - award_year)) |>
  group_by(row_id) |>
  slice_min(city_pop_year_gap, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(row_id, city_pop_thousands, city_pop_year_used = year,
         city_pop_year_gap)

venues <- venues |> left_join(nearest, by = "row_id") |> select(-row_id)

write_csv(venues, "data/processed/worldcup_stadiums_joined.csv")

# ---- 5. Report ----
cat("GDP matched:", sum(!is.na(venues$gdp_per_capita)), "of", nrow(venues), "\n")
cat("CPI matched:", sum(!is.na(venues$cpi_score)), "of", nrow(venues), "\n")
cat("City pop matched:", sum(!is.na(venues$city_pop_thousands)),
    "of", nrow(venues), "\n")
cat("Year gaps used - median:", median(venues$city_pop_year_gap, na.rm = TRUE),
    "| max:", max(venues$city_pop_year_gap, na.rm = TRUE), "\n\n")
cat("Cities with no UN entry at all:\n")
venues |>
  filter(is.na(city_pop_thousands)) |>
  distinct(city_name, country_name) |>
  print(n = 30)