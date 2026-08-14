# Author: MG
# Feature engineering for the venue tables.
# Feature 1: venue_age = how old the venue was at the time of its event,
# i.e. the event year minus the year the venue opened. New builds
# fall near 0; existing venues are higher.

library(tidyverse)
# Fixed reference year for time-since features per Katie's EDA feedback.
# Kept as a constant, not Sys.Date(), so the feature value stays the same no
# matter when the script is run.
AS_OF_YEAR <- 2026

# ---- World Cup: opened_year is already in the joined table ----
wc <- read_csv("data/processed/worldcup_stadiums_joined.csv", show_col_types = FALSE) |>
  mutate(venue_age = tournament_year - opened_year,
         venue_age = if_else(venue_age < 0, NA_real_, venue_age),
         years_since_event = AS_OF_YEAR - tournament_year,
         years_since_construction = AS_OF_YEAR - opened_year)

# ---- Olympic: opened_year comes from the Wikidata pull output ----
ol <- read_csv("data/external/wikidata_olympic_venues.csv", show_col_types = FALSE) |>
  mutate(venue_age = games_year - opened_year,
         venue_age = if_else(venue_age < 0, NA_real_, venue_age),
         years_since_event = AS_OF_YEAR - games_year,
         years_since_construction = AS_OF_YEAR - opened_year)

# ---- Coverage + sanity check ----
cat("World Cup venue_age present:", sum(!is.na(wc$venue_age)), "of", nrow(wc), "\n")
cat("Olympic venue_age present: ", sum(!is.na(ol$venue_age)), "of", nrow(ol), "\n\n")
cat("World Cup years_since_event present:", sum(!is.na(wc$years_since_event)), "of", nrow(wc), "\n")
cat("World Cup years_since_construction present:", sum(!is.na(wc$years_since_construction)), "of", nrow(wc), "\n")
cat("Olympic years_since_event present:", sum(!is.na(ol$years_since_event)), "of", nrow(ol), "\n")
cat("World Cup venue_age summary:\n"); print(summary(wc$venue_age))
cat("\nOlympic venue_age summary:\n"); print(summary(ol$venue_age))

## ---- Feature 2: distance from host-city center (Olympic), in miles ----
library(geosphere)
library(stringi)

# Venue coordinates:
pt <- str_match(ol$coords, "Point\\(\\s*(-?[0-9.]+)\\s+(-?[0-9.]+)")
ol$venue_lon <- as.numeric(pt[, 2])
ol$venue_lat <- as.numeric(pt[, 3])

# Host-city center coordinates from the UN city file (same matching as the join)
clean_key <- function(x) x |> str_replace_all("\u00a0", " ") |>
  stri_trans_general("Latin-ASCII") |> str_to_lower() |> str_squish()
alias <- tribble(~from, ~to,
                 "melbourne / stockholm", "melbourne",
                 "torino", "turin")

un_coords <- read_csv("data/processed/un_city_population_long.csv",
                      show_col_types = FALSE) |>
  mutate(primary = clean_key(str_remove(city, "\\s*\\(.*\\)$")),
         alt = if_else(str_detect(city, "\\("),
                       clean_key(str_extract(city, "(?<=\\().*(?=\\))")),
                       NA_character_)) |>
  pivot_longer(c(primary, alt), values_to = "join_city") |>
  filter(!is.na(join_city)) |>
  group_by(iso3c, join_city) |>
  summarise(city_lon = first(na.omit(lon)),
            city_lat = first(na.omit(lat)), .groups = "drop")

ol <- ol |>
  mutate(join_city = clean_key(host_city)) |>
  left_join(alias, by = c("join_city" = "from")) |>
  mutate(join_city = coalesce(to, join_city)) |> select(-to) |>
  left_join(un_coords, by = c("iso3c", "join_city")) |>
  mutate(distance_mi = if_else(
    !is.na(venue_lon) & !is.na(city_lon),
    distHaversine(cbind(venue_lon, venue_lat), cbind(city_lon, city_lat)) / 1609.34,
    NA_real_))

cat("Olympic distance_mi present:", sum(!is.na(ol$distance_mi)), "of", nrow(ol), "\n")
cat("Olympic distance_mi summary (miles):\n"); print(summary(ol$distance_mi))

# Feature 2: distance from city center (World Cup), in miles.

# Join venue coordinates from the World Cup Wikidata pull by stadium_id.
wc_coords <- read_csv("data/external/wikidata_worldcup_stadiums.csv",
                      show_col_types = FALSE) |>
  select(stadium_id, coords)
wc <- wc |> left_join(wc_coords, by = "stadium_id")

# Parse the WKT "Point(lon lat)" string into numeric longitude and latitude.
wpt <- str_match(wc$coords, "Point\\(\\s*(-?[0-9.]+)\\s+(-?[0-9.]+)")
wc$venue_lon <- as.numeric(wpt[, 2])
wc$venue_lat <- as.numeric(wpt[, 3])

# City aliases from 04_join_country_data.R 
wc_alias <- tribble(
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
  "port elizabeth",  "gqeberha",
  "nelspruit",       "mbombela",
  "oviedo",          "oviedo / uvieu",
  "elche",           "elx / elche",
  "san jose",        "san francisco",
  "stanford",        "san francisco"
)

# Match each stadium's city to its UN center coordinate, then compute distance.
wc <- wc |>
  mutate(join_city = clean_key(city_name)) |>
  left_join(wc_alias, by = c("join_city" = "from")) |>
  mutate(join_city = coalesce(to, join_city)) |> select(-to) |>
  left_join(un_coords, by = c("iso3c", "join_city")) |>
  mutate(distance_mi = if_else(
    !is.na(venue_lon) & !is.na(city_lon),
    distHaversine(cbind(venue_lon, venue_lat), cbind(city_lon, city_lat)) / 1609.34,
    NA_real_))

cat("World Cup distance_mi present:", sum(!is.na(wc$distance_mi)), "of", nrow(wc), "\n")
cat("World Cup distance_mi summary (miles):\n"); print(summary(wc$distance_mi))

write_csv(wc |> select(-join_city), "data/processed/worldcup_stadiums_features.csv")
write_csv(ol |> select(-join_city), "data/processed/olympic_venues_features.csv")
