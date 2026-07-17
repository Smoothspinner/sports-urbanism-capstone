# This script turns 3 raw data sources (World Bank income, corruption scores
# UN city populations) into clean tables ready to join to the venue list.
# Outputs saved in data/processed

library(tidyverse)
library(readxl)
library(WDI)
library(countrycode)

# ---- 1. Country income ----
# Downloads GDP per person by country and year from the World Bank.
gdp <- WDI(indicator = "NY.GDP.PCAP.CD", start = 1960, end = 2026) |>
  rename(gdp_per_capita = NY.GDP.PCAP.CD) |>
  select(iso3c, country, year, gdp_per_capita) |>
  filter(!is.na(gdp_per_capita))

write_csv(gdp, "data/processed/worldbank_gdp_per_capita_long.csv")

# ---- 2. Corruption scores ----
# Reads the Transparency International spreadsheet.
# Keeps country, year, and score (2012-2025)
cpi <- read_excel("data/raw/CPI2025_Results.xlsx",
                  sheet = "CPI Historical", skip = 3) |>
  select(country = `Country / Territory`, iso3c = ISO3,
         year = Year, cpi_score = `CPI score`) |>
  filter(!is.na(cpi_score))

write_csv(cpi, "data/processed/cpi_2012_2025_long.csv")

# ---- 3. City populations ----
# Reads the UN city population spreadsheet (1975-2050) and reshapes it
# to one row per city per year, keeping coordinates for the distance predictor.
un <- read_excel("data/raw/WUP2025-F21-DEGURBA-Cities_Pop.xlsx",
                 sheet = "Data") |>
  select(country = Location, iso3c = ISO3_Code, city_code = City_Code,
         city = City_Name, lon = PWCent_Longitude, lat = PWCent_Latitude,
         matches("^[0-9]{4}")) |>
  pivot_longer(matches("^[0-9]{4}"),
               names_to = "year", values_to = "pop_thousands") |>
  mutate(year = as.integer(as.numeric(year))) |>
  filter(!is.na(pop_thousands), year <= 2026)

write_csv(un, "data/processed/un_city_population_long.csv")

# Prints a quick summary so we know it worked.
cat("Done. Rows written - GDP:", nrow(gdp), "| CPI:", nrow(cpi),
    "| UN cities:", nrow(un), "\n")