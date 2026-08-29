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
- `source/data`: cleaning and join scripts (numbered in run order: 01_, 02_...)
- `source/features`: feature engineering and exploratory scripts (13, 15, 21)
- `source/models`: tuned Sprint 6 models, one subfolder per model: `baseline` (14),
  `penalized_logistic` (18, 19), `GBM` (17), `RF` (16, 16b). `20_threshold_range_reporting.R`
  sits at the top level since it evaluates all three models together rather than
  belonging to one.
- `source/visualization`: plotting scripts
- `reports`: weekly deliverables (proposal, EDA, etc.)

## How to Run
1. Open the project in RStudio.
2. Set the working directory to the repo root: **Session > Set Working
   Directory > Choose Directory**, then select the top-level project folder,
   the one that contains this README file and the `source` and `data` folders.
   Scripts use paths relative to the repo root, so this step is required every session.
3. Install any missing packages: `tidyverse, countrycode, geosphere,
   stringi, httr, jsonlite, readxl, WDI, caret, pROC, glmnet, gbm` (MASS
   installs automatically with caret).
4. Run the scripts in `source/data` in order (01 through 12), then the
   scripts in `source/features` (13, 15). Run `21_final_eda.R` after 12,
   since it reads the split file and writes the report's Data Exploration
   figures.
5. For Sprint 6 modeling, run `source/models/penalized_logistic/18_penalized_logistic.R`,
   `source/models/RF/16_random_forest.R`, and `source/models/GBM/17_gradient_boosting.R`.
   These three are independent of each other and can be run in any order. Run
   `source/models/20_threshold_range_reporting.R` last, since it depends on all
   three already being loaded in the same R session.
   `source/models/RF/16b_random_forest_region_check.R` and
   `source/models/penalized_logistic/19_penalized_logistic_capacity_check.R` are
   standalone diagnostics, not required to reproduce the main results.

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
| 15 | `15_missingness_diagnostic.R` | Reproduces Table 1: tests each imputed predictor's missing-flag against the outcome (Fisher's exact test) |
| 16 | `16_random_forest.R` | Random forest, Sprint 6's second tunable model. Grouped Olympic-edition cross-validation, tunes `mtry` |
| 16b | `16b_random_forest_region_check.R` | Diagnostic: what adding region as a predictor costs the random forest, holding rows, folds, and `mtry` fixed |
| 17 | `17_gradient_boosting.R` | Gradient boosting, Sprint 6's third tunable model. Grouped CV, tunes number of trees, tree depth, and learning rate |
| 18 | `18_penalized_logistic.R` | Elastic net (glmnet) penalized logistic regression, Sprint 6's first tunable model. Grouped CV, tunes alpha and lambda jointly |
| 19 | `19_penalized_logistic_capacity_check.R` | Diagnostic: whether dropping log capacity for region costs real signal in the elastic net |
| 20 | `20_threshold_range_reporting.R` | Evaluates classification thresholds as a range across all three tuned models, rather than one single cutoff |
| 21 | `21_final_eda.R` | EDA on the final modeling dataset for the Sprint 7 report. Writes five figures to `reports/EDA/final/` |

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
| `make_grouped_folds()` | 16, 16b, 17, 18 | Builds cross-validation folds that keep every venue from the same Olympic edition in one fold, so no edition splits across training and validation. Defined separately in each of these four scripts rather than shared from one place. |
| `best_oof_predictions()` | 20 | Filters a caret model's saved predictions down to just its selected tuning parameters |
| `threshold_metrics()` | 20 | Computes sensitivity, specificity, precision, and F1 at one probability threshold |
| `make_threshold_report()` | 20 | Runs `threshold_metrics()` across a grid of thresholds for one model |

## Contributors
- Jonathan Layne: unsupervised analysis (13), random forest (16, 16b), report assembly, reviewed code directly and caught errors before submission
- Brian Wrenn: sourced and coded the venue status/closure-reason raw data, the basis for our target variable; gradient boosting (17); threshold-range reporting (20)
- Martin Gotora: full data pipeline (01-12), baseline models (14), elastic net / penalized logistic regression (18, 19)
