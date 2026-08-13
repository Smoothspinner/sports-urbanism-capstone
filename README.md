# Predicting White Elephant Risk in Olympic and World Cup Venues Using Machine Learning
*Working title - DSE 6311 Capstone, Team Gamma*

**Team:** Brian Wrenn, Jonathan Layne, Martin Gotora

## Background
Some Olympic and World Cup venues fall out of use after their event, becoming
"white elephants" that consume public money with little return. Prior research
explains these failures after the fact, no work we have found tries to predict
them before construction begins.

## Why It Matters
Cities commit public money to venues years before they exist. An early-warning
model flags bad plans on paper, not after a half-built stadium. Prior work
(Alm et al. 2016; Müller 2015) explains venue failures after the fact; no study
we have found trains a predictive model and tests it on venues it never saw.

## Stakeholders
Host-city bid committees and government planning offices.

## Question
Can pre-construction information (design purpose, capacity, event type,
host-country income and corruption, bid-tied status, host-city population)
predict whether a venue stays in active use or becomes a white elephant?

## Hypothesis
Venues that are bid-tied, single-purpose, and hard to reach become white
elephants more often, because long-term use was never the point of building them.

## Prediction
Bid-tied status and design purpose will emerge as the strongest predictors,
and the model will outperform a naive baseline that always predicts "stays active."

## Where files go
- `data/raw`: original downloads, untouched, keep original filenames
- `data/processed`: cleaned tables our scripts produce
- `data/external`: reference pulls (e.g., Wikidata)
- `source/features`: feature engineering and modeling scripts currently in use (13, 14)
- `source/models`: model scripts, subfolders `baseline`, `GBM`, `RF`
- `source/visualization`: plotting scripts
- `reports`: weekly deliverables (proposal, EDA, etc.)
  
## How to Run
1. Open the project in RStudio.
2. Set the working directory to the repo root: **Session > Set Working
   Directory > Choose Directory**, then select the top-level project folder,
   the one that contains this README file and the `source` and `data` folders.
   Scripts use paths relative to the repo root, so this step is required every session.
4. Install any missing packages: `tidyverse, countrycode, geosphere,
   stringi, httr, jsonlite, readxl, WDI, caret, pROC` (MASS installs
   automatically with caret).
5. Run the scripts in `source/data` in order (01 through 12), then the
   scripts in `source/features` (13, 14).

| # | Script | What it does |
|---|--------|---------------|
| 01 | `01_clean_income_corruption_population.R` | Cleans World Bank GDP, Transparency International CPI, and UN city population into long-format reference tables |
| 02 | `02_wikidata_worldcup_pull.R` | Pulls World Cup stadium facts (coordinates, capacity, opening year) from Wikidata |
| 03 | `03_award_years.R` | Builds the hosting award-year table for World Cup and Olympics |
| 04 | `04_join_country_data.R` | Joins country/city reference data to World Cup venues; ranks city population against the full UN panel |
| 05 | `05_olympic_games_lookup.R` | Builds the Olympic Games lookup table (host city, year, precision notes) |
| 06 | `06_join_olympic_data.R` | Joins country/city reference data and the coded closure-reason target to Olympic venues; ranks city population against the full UN panel |
| 07 | `07_wikidata_olympic_pull.R` | Matches Olympic venues to Wikidata pages by name + host city and pulls coordinates, capacity, opening year |
| 08 | `08_review_olympic_wiki.R` | Manual review pass, rejects incorrect Wikidata matches found in script 07 |
| 09 | `09_feature_engineering.R` | Builds venue age, years-since-event, years-since-construction, and distance-from-city-center features |
| 10 | `10_cleaning_transforms.R` | Log transforms, era/region grouping, the `white_elephant` target definition, GDP percentile rank |
| 11 | `11_train_test_split.R` | Stratified, venue-grouped train/test split; capacity percentile rank (computed after the split, no external panel exists for it) |
| 12 | `12_missing_values.R` | Adds missing-value flags and train-only median imputation for each numeric predictor |
| 13 | `13_unsupervised_pca_kmeans.R` | PCA and k-means exploration of the feature space |
| 14 | `14_baseline_models.R` | Logistic regression and LDA baseline classifiers, cross-validated |

## Data Sources
- **World Bank** (via the `WDI` package): GDP per capita, 1960-2026
- **Transparency International**: Corruption Perceptions Index, 2012-2025
- **UN World Population Prospects**: city population, 1975-2050 (capped at 2026)
- **Wikidata** (SPARQL): venue coordinates, seating capacity, opening/inception year
- **Wikipedia Search API**: matches Olympic venue names to Wikidata pages (IOC data has no direct links)
- **VenueReportsV4.xlsx**: venue status and coded closure reasoning, the source of our target variable

## Custom Functions
| Function | Where | What it does |
|---|---|---|
| `clean_key()` | 04, 06, 09 | Normalizes city names (accents, spacing, casing) for joining across sources |
| `nan_to_na()` | 06, 10, 11 | Converts the `NaN` that `percent_rank()`/`scale()` return for single-value groups into `NA` |
| `add_flags_impute()` | 12 | Adds a `_missing` flag and a train-median-imputed `_imp` column for a given predictor |
| `rank_within_train()` | 11 | Percentile rank and z-score of a value against the training set's distribution only, by award year |
| `search_title()`, `iri()` | 07 | Find and format the Wikipedia page most likely matching a venue name + host city |
| `best_cut()` | 14 | Picks the classification threshold that balances sensitivity and specificity (Youden's J) from pooled cross-validation predictions |

## Contributors
- Jonathan Layne: unsupervised analysis (13), report assembly
- Brian Wrenn: venue status/closure-reason coding (source data for the target)
- Martin Gotora: feature engineering (09), cleaning/target definition (10),
  train/test split (11), missing values (12), baseline models (14)

Martin ran the full pipeline end to end for each submission. Jay reviewed the code directly and caught errors before the report went out.
