# Data Dictionary

Columns in the two joined venue tables as of the EDA stage. The
country-level columns (GDP, CPI, city population) are measured at each
edition’s award year. The white-elephant target is not stored here; it
gets built from status and reason at the modeling stage.

## worldcup_stadiums_joined.csv (265 rows)

| column | type | notes |
|----|----|----|
| venue_id, stadium_id | id | row / stadium keys |
| stadium_name, city_name, country_name | text | venue and host |
| tournament_id, tournament_year | id / number | which World Cup (the unit we split on) |
| award_year | number | year the World Cup was awarded; join key for country data |
| opened_year | number | year the stadium opened |
| stadium_capacity | number | seats |
| design_purpose | category | Single-purpose or Multi-purpose |
| newly_built | category | New or Existing at the time of the tournament |
| current_status | category | in use or not in use |
| status_detail | text | extra detail (rebuilt 2007, demolished 2002, etc.) |
| not_in_use_reason | category | replaced / urban redevelopment / abandoned / war |
| wikipedia_link | text | source page |
| iso3c | text | country code |
| gdp_per_capita | number | host GDP per capita at award year (World Bank) |
| cpi_score | number | host corruption score (only exists 2012 on) |
| city_pop_thousands | number | host city population (nearest UN year) |
| city_pop_year_used | number | which UN year was used |
| city_pop_year_gap | number | gap between award year and the UN year |
| region | category | added in EDA, continental group |
| era | category | added in EDA, pre-WWII / postwar / recent |

## olympic_venues_joined.csv (983 rows)

| column | type | notes |
|----|----|----|
| venue_name | text | venue |
| venue_classification | text | New / Existing / Temporary / Mixed (raw, needs cleaning) |
| use_at_games | text | sport(s) it was used for |
| current_status | text | raw status, has ~17 spellings, cleaned in EDA |
| games_year, host_city, host_country | number / text | which Games |
| award_year | number | join key for country data |
| precision | text | how exact the venue location is |
| iso3c | text | country code |
| gdp_per_capita, cpi_score, city_pop_thousands | number | same as World Cup side |
| city_pop_year_used, city_pop_year_gap | number | same as World Cup side |
| status_group | category | added in EDA, in use / not in use / dismantled |
| build_group | category | added in EDA, New / Existing / Temporary / Mixed |
| region, era | category | added in EDA |

## Gaps at this stage

- We have not yet coded, venue by venue, the cause each out-of-use
  Olympic venue closed for (abandoned / replaced / redevelopment / war),
  the way we did for the World Cup side. Appendix 1 of the IOC report
  classifies a venue as in use or not from current activity, but does
  not say which cause applies, and only some causes count as a white
  elephant. Olympic side also has no single/multi-purpose field.

- No per-venue capacity for the Olympic venues (only in the report
  text).

- Distance to city center is a planned predictor but not built yet.

- CPI only starts in 2012, so it is mostly missing on older editions.
