# Data Dictionary: Sprint 4 (Preprocessing & Feature Engineering)

Current as of the Sprint 4 modelling tables. This supersedes the EDA-stage
dictionary at `reports/EDA/data_dictionary.md`, which describes the earlier
joined tables before feature engineering, splitting and imputation.

Two tables are carried in parallel, one per event type:

| File | Rows | Columns |
|----|----|----|
| `data/processed/olympic_model_split.csv` | 875 | 77 |
| `data/processed/worldcup_model_split.csv` | 265 | 73 |

Olympic rows are one venue at one Games. World Cup rows are one stadium at one
tournament, so a stadium used at two tournaments appears twice.

---

## 1. Identifiers and source fields

### Olympic

| Column | Type | Notes |
|----|----|----|
| `venue_name` | text | Venue name as printed in the IOC report |
| `venue_classification` | text | Raw IOC classification: New, Existing, Temporary, Mixed |
| `use_at_games` | text | Sport or sports the venue hosted |
| `current_status` | text | Raw status from the IOC report; the source of the target |
| `games_year` | number | Year the Games were held |
| `host_city`, `host_country` | text | Host of those Games |
| `award_year` | number | Year the Games were awarded; the join key for country data |
| `iso3c` | text | Three-letter country code. Blank for the USSR and Yugoslavia, which no longer exist |
| `page_title`, `wikidata_id`, `wikidata_name`, `types` | text | Match keys and result fields from the Wikidata pull |
| `coords`, `precision` | text / number | Venue coordinate as returned by Wikidata, and its stated precision |

### World Cup

| Column | Type | Notes |
|----|----|----|
| `venue_id`, `stadium_id` | id | Row key and stadium key. `stadium_id` is the unit the split is grouped on |
| `stadium_name`, `city_name`, `country_name` | text | Venue and host |
| `tournament_id`, `tournament_year` | id / number | Which World Cup |
| `award_year` | number | Year the tournament was awarded; join key for country data |
| `design_purpose` | category | Single-purpose or Multi-purpose |
| `newly_built` | category | New or Existing at the time of the tournament |
| `current_status` | category | in use or not in use |
| `status_detail` | text | Free text, for example "demolished 2002" |
| `not_in_use_reason` | category | replaced / urban redevelopment / abandoned / war |
| `wikipedia_link` | text | Source page |
| `iso3c` | text | Country code |
| `coords` | text | Stadium coordinate from the Wikidata pull |

---

## 2. Country and city context, measured at the award year

Present in both tables. Measured at the year the event was awarded rather than
the year it was held, because award year is when the building decision was made.

| Column | Type | Notes |
|----|----|----|
| `gdp_per_capita` | number | Host country GDP per capita, World Bank |
| `cpi_score` | number | Host country corruption perceptions score. Only exists from 2012, so it is almost entirely missing and is not used as a predictor |
| `city_pop_thousands` | number | Host city population, UN World Urbanization Prospects |
| `city_pop_year_used` | number | Which UN year was actually used |
| `city_pop_year_gap` | number | Distance in years between the award year and the UN year used |
| `capacity_wd` (Olympic) | number | Seating capacity from Wikidata |
| `stadium_capacity` (World Cup) | number | Seating capacity from the Fjelstul database |
| `opened_year` | number | Year the venue opened |
| `opened_year_source` (Olympic) | text | Which Wikidata property supplied it: P1619 (official opening) or P571 (inception, used as a fallback) |

---

## 3. Engineered features

| Column | Type | Built from | Notes |
|----|----|----|----|
| `venue_age` | number | event year minus `opened_year` | How old the venue was at its own event. New builds sit near zero. Negative values are set to missing |
| `years_since_event` | number | 2026 minus event year | How long the venue has had to fail since its event |
| `years_since_construction` | number | 2026 minus `opened_year` | Total age today |
| `venue_lon`, `venue_lat` | number | parsed from `coords` | Venue coordinate |
| `city_lon`, `city_lat` | number | UN city file | Host city centre coordinate |
| `distance_mi` | number | Haversine distance | Miles from the venue to the host city centre |
| `log_capacity`, `log_gdp`, `log_city_pop`, `log_distance` | number | `log1p()` of the source column | All four are right-skewed in raw form |
| `class_group` (Olympic) | category | `venue_classification` | Cleaned to Existing / New / Temporary |
| `new_build` | 0/1 | `class_group` or `newly_built` | 1 = built for the event, 0 = already existed. Missing for the 11 Olympic rows classified Temporary |
| `single_purpose` (World Cup) | 0/1 | `design_purpose` | 1 = single-purpose |
| `era` | category | event year | pre-WWII (to 1945), postwar (1946 to 2000), recent (2001 on) |
| `region` | category | host country | Continental group |
| `status_clean`, `status_group` (Olympic) | text | `current_status` | Whitespace and case normalised, then bucketed to in use / not in use / temporary |
| `vid` (Olympic) | text | venue name plus host city | The unit the split is grouped on |

`AS_OF_YEAR` is fixed at 2026 rather than read from the system clock, so the
time-since features do not change value depending on when the script is run.

---

## 4. Rank and standardised versions

For three variables the table also carries a within-group rank and a
standardised score. Both are computed per `award_year`, except the GDP pair,
which is ranked against every World Bank country in that year rather than only
against host countries.

| Column | Type | Notes |
|----|----|----|
| `gdp_pct_rank`, `gdp_z` | number | Ranked against all World Bank countries that year |
| `city_pop_pct_rank`, `city_pop_z` | number | Ranked among host venues in the same award year |
| `capacity_pct_rank`, `capacity_z` | number | Ranked among host venues in the same award year. Thin on the Olympic side, see the missingness note in the report |

A percentile rank over a group of one returns no value, so these columns are
missing for any award year with a single usable venue.

---

## 5. Split and missing-value columns

| Column | Type | Notes |
|----|----|----|
| `white_elephant` | TRUE / FALSE | The target. TRUE where the cleaned status is "not in use". Missing, and therefore dropped, for temporary and dismantled venues |
| `set` | text | `train` or `test` |

For each of the 13 numeric predictors below, the table carries two extra
columns, giving 26 columns per table:

- `<variable>_missing`: 1 if the original value was missing, 0 otherwise
- `<variable>_imp`: the original value, or the **training-set** median where it was missing

The 13 variables are: `log_capacity`, `log_gdp`, `log_city_pop`,
`log_distance`, `venue_age`, `years_since_event`, `years_since_construction`,
`gdp_pct_rank`, `gdp_z`, `city_pop_pct_rank`, `city_pop_z`,
`capacity_pct_rank`, `capacity_z`.

Medians are taken from training rows only. Test rows are filled using the
training median, never their own, so nothing about the test set reaches the
model during fitting.

---

## 6. Columns added by the unsupervised step

`source/features/13_unsupervised_pca_kmeans.R` fits on the training rows and
writes its output to figures rather than back into the modelling tables. No
principal component or cluster label is carried forward as a predictor. See the
Results section of the Sprint 4 report for why.
