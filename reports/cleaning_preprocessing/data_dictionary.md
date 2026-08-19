# Data Dictionary: Modeling Tables

Current as of the Sprint 5 target freeze, covering the same preprocessing and
feature engineering as the Sprint 4 report. This supersedes the EDA-stage
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
| `reasoning` | text | Why a closed venue closed, coded from the V4 venue reports: abandoned before demolition, urban redevelopment, replaced by successor stadium, or war. Blank for venues still in use. Read together with `current_status` to set the target. The World Cup equivalent is `not_in_use_reason` |
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

Design purpose comes from the stadium's Wikipedia article, based on how the
opening description characterizes the venue. A stadium described there as a
football ground is recorded as Single-purpose, and one described as a multi-use
or multi-purpose venue is recorded as Multi-purpose. On stadiums rebuilt
between tournaments the label is judged per appearance, so the same venue can
be Multi-purpose in one row and Single-purpose in another.

The Olympic table carries no design purpose column. The IOC report does not
record one, and the criterion above has not been applied to Olympic venues.

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
| `city_lon`, `city_lat` | number | UN city file | Host city center coordinate |
| `distance_mi` | number | Haversine distance | Miles from the venue to the host city center |
| `log_capacity`, `log_gdp`, `log_city_pop`, `log_distance` | number | `log1p()` of the source column | All four are right-skewed in raw form |
| `class_group` (Olympic) | category | `venue_classification` | Cleaned to Existing / New / Temporary |
| `new_build` | 0/1 | `class_group` or `newly_built` | 1 = built for the event, 0 = already existed. Missing for the 11 Olympic rows classified Temporary |
| `single_purpose` (World Cup) | 0/1 | `design_purpose` | 1 = single-purpose |
| `era` | category | event year | pre-WWII (to 1945), postwar (1946 to 2000), recent (2001 on) |
| `region` | category | host country | Continental group |
| `status_clean`, `status_group` (Olympic) | text | `current_status` | Whitespace and case normalized, then bucketed to in use / not in use / temporary |
| `vid` (Olympic) | text | venue name plus host city | The unit the split is grouped on |

`AS_OF_YEAR` is fixed at 2026 rather than read from the system clock, so the
time-since features do not change value depending on when the script is run.

---

## 4. Rank and standardized versions

For three variables the table also carries a rank and a standardized score.
The GDP and city population pairs are scored against outside reference data for
that year rather than against the rows in this project. Capacity is scored per
`award_year` against training rows only, since there is no outside panel of
stadium sizes to rank against.

| Column | Type | Notes |
|----|----|----|
| `gdp_pct_rank`, `gdp_z` | number | Ranked against all World Bank countries that year |
| `city_pop_pct_rank`, `city_pop_z` | number | Ranked against every city in the UN population file for that year |
| `capacity_pct_rank`, `capacity_z` | number | Ranked against training rows in the same award year. Missing for the same 739 Olympic rows that carry no capacity value, so the gap is inherited from the source column rather than created here. See the missingness note in the report |

The capacity pair is built in `11_train_test_split.R` rather than in script 10,
scored against the training rows for that award year only. Computing it before
the split let test rows influence the distribution the training scores were
compared against. Each rank is the share of training values at or below the
row's own value. GDP is built in script 10 and city population in scripts 04
and 06, both scored against outside data, so the split does not reach them.
The `percent_rank()` behind the ranks quoted in the Sprint 4 EDA report is a
different statistic.

A percentile over a group of one returns 1, and a group with no spread has a
standard deviation of zero, so the z-score is undefined. Ranking city
population within our own rows hit both problems, since each Games has one host
city, and the rank came back at the same value nearly every time. Ranking
against the full UN file fixed it: of 875 Olympic rows, `city_pop_pct_rank` is
now 1 for 26 and missing for 118, with `city_pop_z` missing for the same 118.
Capacity still carries the group-size limitation, and a value is missing where
the award year has no usable training rows.

---

## 5. Split and missing-value columns

| Column | Type | Notes |
|----|----|----|
| `white_elephant` | TRUE / FALSE | The target. TRUE only where the status is "not in use" and the closure reason is "abandoned before demolition". Every other closed venue is FALSE. Missing, and therefore dropped, for temporary and dismantled venues |
| `set` | text | `train` or `test` |

The target was narrowed at the start of Sprint 5. Every "not in use" venue
previously counted as a failure, so a stadium replaced by a successor scored
the same as one left standing empty. The definition now reads the closure
reason as well, taken from the coding in the V4 venue reports. Replaced by
successor and war are never failures. Urban redevelopment is held behind a
switch at the top of `10_cleaning_transforms.R`,
`REDEVELOPMENT_COUNTS_AS_FAILURE`, currently FALSE. Setting it to TRUE moves 69
Olympic and 5 World Cup venues into the positive class.

The positive class holds 26 of 875 Olympic rows and 4 of 265 World Cup rows, so
accuracy is not a usable score on either table.

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
writes its output to figures rather than back into the modeling tables. No
principal component or cluster label is carried forward as a predictor. See the
Results section of the Sprint 4 report for why.
