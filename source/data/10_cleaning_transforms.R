# Cleaning and transforms -> model-ready tables.
# white_elephant frozen (Aug 2026): only "abandoned before demolition" counts
# as a failure. Replaced-by-successor and war are never failures.

library(tidyverse)
library(countrycode)

# Sensitivity toggle Jay raised: a city might clear a site for redevelopment
# precisely because the venue had already failed, so "not a failure" isn't a
# safe assumption for those 69 (Olympic) / 5 (World Cup) rows. Default is the
# team's main reading (FALSE); flip to TRUE to test the alternate one.
REDEVELOPMENT_COUNTS_AS_FAILURE <- FALSE

# NaN -> NA. percent_rank()/scale() divide by (n-1), so an award year with a
# single usable venue returns NaN instead of a real value; treated as an
# ordinary missing value rather than a distinct case downstream.
nan_to_na <- function(x) if_else(is.nan(x), NA_real_, x)

# GDP rank per year, all World Bank countries, not just this dataset's hosts.
# Computed here (before the split) rather than after it like the population
# and capacity ranks below, because it's scored against an external panel,
# not against other rows in this dataset, so there's no train/test leakage.
gdp_global <- read_csv("data/processed/worldbank_gdp_per_capita_long.csv", show_col_types = FALSE) |>
  mutate(year = as.integer(year)) |>
  filter(!is.na(countrycode(iso3c, "iso3c", "country.name"))) |>
  group_by(year) |>
  mutate(gdp_pct_rank = nan_to_na(percent_rank(gdp_per_capita)),
         gdp_z        = nan_to_na(as.numeric(scale(gdp_per_capita)))) |>
  ungroup() |>
  select(iso3c, year, gdp_pct_rank, gdp_z)

# ---- World Cup ----
wc <- read_csv("data/processed/worldcup_stadiums_features.csv",
               show_col_types = FALSE) |>
  mutate(
    # Capacity, GDP, population and distance are all right-skewed; log1p pulls
    # in the long tail without producing -Inf on any zero-valued rows.
    log_capacity   = log1p(stadium_capacity),
    log_gdp        = log1p(gdp_per_capita),
    log_city_pop   = log1p(city_pop_thousands),
    log_distance   = log1p(distance_mi),
    new_build      = if_else(newly_built == "New", 1L, 0L),
    single_purpose = if_else(design_purpose == "Single-purpose", 1L, 0L),
    # Only genuine abandonment counts as a failure. Replaced-by-successor and
    # war are never failures; redevelopment is controlled by the toggle above.
    white_elephant = case_when(
      current_status == "not in use" & not_in_use_reason == "abandoned before demolition" ~ TRUE,
      current_status == "not in use" & not_in_use_reason == "urban redevelopment" & REDEVELOPMENT_COUNTS_AS_FAILURE ~ TRUE,
      current_status == "not in use" ~ FALSE,
      current_status == "in use"     ~ FALSE),
    # 1945 (end of WWII) and 2000 (end of the 20th century) split venues into
    # three eras of roughly comparable construction norms and stadium design.
    era = case_when(tournament_year <= 1945 ~ "pre-WWII",
                    tournament_year <= 2000 ~ "postwar",
                    TRUE                    ~ "recent"),
    region = countrycode(country_name, "country.name", "continent",
                         custom_match = c("England" = "Europe"))
  ) |>
  left_join(gdp_global, by = c("iso3c", "award_year" = "year"))

# ---- Olympic ----
ol <- read_csv("data/processed/olympic_venues_features.csv",
               show_col_types = FALSE) |>
  mutate(
    class_clean = venue_classification |> str_replace_all("[\r\n]+", " ") |>
      str_squish() |> str_to_lower(),
    # Mixed-use construction folds into New, since it isn't a clean Existing
    # case either.
    class_group = case_when(str_starts(class_clean, "existing")  ~ "Existing",
                            str_starts(class_clean, "temporary") ~ "Temporary",
                            TRUE                                 ~ "New"),
    # Undefined for Temporary: built-for-the-event vs pre-existing doesn't
    # apply the same way to a structure erected and torn down for one Games.
    new_build = case_when(class_group == "New"      ~ 1L,
                          class_group == "Existing" ~ 0L,
                          TRUE                      ~ NA_integer_),
    status_clean = current_status |> str_replace_all("[\r\n]+", " ") |>
      str_squish() |> str_to_lower(),
    status_group = case_when(str_starts(status_clean, "dismantled") ~ "temporary",
                             str_starts(status_clean, "not in use") ~ "not in use",
                             str_starts(status_clean, "in use")     ~ "in use"),
    # Only genuine abandonment counts as a failure. Replaced-by-successor and
    # war are never failures; redevelopment is controlled by the toggle above.
    # Temporary venues stay NA here (excluded, not FALSE), since "built to be
    # torn down" isn't part of the failure question this target measures.
    white_elephant = case_when(
      status_group == "not in use" & str_starts(reasoning, "abandoned before demolition") ~ TRUE,
      status_group == "not in use" & str_starts(reasoning, "urban redevelopment") & REDEVELOPMENT_COUNTS_AS_FAILURE ~ TRUE,
      status_group == "not in use" ~ FALSE,
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
  ) |>
  left_join(gdp_global, by = c("iso3c", "award_year" = "year"))

# ---- Verification ----
cat("== World Cup ==\n")
cat("new_build:\n");       print(count(wc, new_build))
cat("single_purpose:\n"); print(count(wc, single_purpose))
cat("white_elephant:\n"); print(count(wc, white_elephant))
cat("era:\n");            print(count(wc, era))
cat("region:\n");         print(count(wc, region))
cat("log ranges:\n")
print(summary(select(wc, log_capacity, log_gdp, log_city_pop, log_distance)))
cat("gdp rank range:\n")
print(summary(select(wc, gdp_pct_rank, gdp_z)))

cat("\n== Olympic ==\n")
cat("class_group:\n");    print(count(ol, class_group))
cat("new_build:\n");      print(count(ol, new_build))
cat("white_elephant:\n");print(count(ol, white_elephant))
cat("era:\n");            print(count(ol, era))
cat("region:\n");         print(count(ol, region))
cat("gdp rank range:\n")
print(summary(select(ol, gdp_pct_rank, gdp_z)))

# ---- Save ----
write_csv(wc, "data/processed/worldcup_model.csv")
write_csv(ol, "data/processed/olympic_model.csv")
cat("\nSaved worldcup_model.csv and olympic_model.csv\n")