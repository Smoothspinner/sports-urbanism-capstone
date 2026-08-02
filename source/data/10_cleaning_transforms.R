# Cleaning and transforms -> model-ready tables.
# Model with the log_ columns, not the raw ones (same info, avoids double-counting).
# white_elephant is decided from status for now; Brian's reason coding will refine it later.

library(tidyverse)
library(countrycode)

# ---- World Cup ----
wc <- read_csv("data/processed/worldcup_stadiums_features.csv",
               show_col_types = FALSE) |>
  mutate(
    log_capacity   = log1p(stadium_capacity),
    log_gdp        = log1p(gdp_per_capita),
    log_city_pop   = log1p(city_pop_thousands),
    log_distance   = log1p(distance_mi),
    new_build      = if_else(newly_built == "New", 1L, 0L),
    single_purpose = if_else(design_purpose == "Single-purpose", 1L, 0L),
    white_elephant = case_when(current_status == "not in use" ~ TRUE,
                               current_status == "in use"     ~ FALSE),
    era = case_when(tournament_year <= 1945 ~ "pre-WWII",
                    tournament_year <= 2000 ~ "postwar",
                    TRUE                    ~ "recent"),
    region = countrycode(country_name, "country.name", "continent",
                         custom_match = c("England" = "Europe"))
  )

# ---- Olympic ----
ol <- read_csv("data/processed/olympic_venues_features.csv",
               show_col_types = FALSE) |>
  mutate(
    class_clean = venue_classification |> str_replace_all("[\r\n]+", " ") |>
      str_squish() |> str_to_lower(),
    class_group = case_when(str_starts(class_clean, "existing")  ~ "Existing",
                            str_starts(class_clean, "temporary") ~ "Temporary",
                            TRUE                                 ~ "New"),   # Mixed -> New
    new_build = case_when(class_group == "New"      ~ 1L,
                          class_group == "Existing" ~ 0L,
                          TRUE                      ~ NA_integer_),
    status_clean = current_status |> str_replace_all("[\r\n]+", " ") |>
      str_squish() |> str_to_lower(),
    status_group = case_when(str_starts(status_clean, "dismantled") ~ "temporary",
                             str_starts(status_clean, "not in use") ~ "not in use",
                             str_starts(status_clean, "in use")     ~ "in use"),
    white_elephant = case_when(status_group == "not in use" ~ TRUE,
                               status_group == "in use"     ~ FALSE),
    log_capacity = log1p(capacity_wd),
    log_gdp      = log1p(gdp_per_capita),
    log_city_pop = log1p(city_pop_thousands),
    log_distance = log1p(distance_mi),
    era = case_when(games_year <= 1945 ~ "pre-WWII",
                    games_year <= 2000 ~ "postwar",
                    TRUE               ~ "recent"),
    region = countrycode(host_country, "country.name", "continent",
                         custom_match = c("West Germany" = "Europe",
                                          "Soviet Union" = "Europe",
                                          "Yugoslavia"   = "Europe"))
  )

# ---- Verification ----
cat("== World Cup ==\n")
cat("new_build:\n");       print(count(wc, new_build))
cat("single_purpose:\n"); print(count(wc, single_purpose))
cat("white_elephant:\n"); print(count(wc, white_elephant))
cat("era:\n");            print(count(wc, era))
cat("region:\n");         print(count(wc, region))
cat("log ranges:\n")
print(summary(select(wc, log_capacity, log_gdp, log_city_pop, log_distance)))

cat("\n== Olympic ==\n")
cat("class_group:\n");    print(count(ol, class_group))
cat("new_build:\n");      print(count(ol, new_build))
cat("white_elephant:\n");print(count(ol, white_elephant))
cat("era:\n");            print(count(ol, era))
cat("region:\n");         print(count(ol, region))

# ---- Save ----
write_csv(wc, "data/processed/worldcup_model.csv")
write_csv(ol, "data/processed/olympic_model.csv")
cat("\nSaved worldcup_model.csv and olympic_model.csv\n")