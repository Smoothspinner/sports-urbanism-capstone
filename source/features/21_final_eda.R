# Author: JL
# EDA on the final modeling dataset, for the S7 report. The Sprint 3 EDA ran
# on the joined table before the outcome was frozen, so it counted a different
# variable and is not reused. Everything here reads the split file the models
# are actually fitted on. Run from the repo root.

# Written as a new script rather than as an edit to reports/EDA/eda.R. That
# script reads a different input, covers the World Cup arm as well, and two of
# the figures it writes are embedded in the Sprint 3 report we submitted, so
# rerunning an edited copy would overwrite them.

# Reran this from the repo root on 2026-08-30 and it ran without error. The
# five figures it writes matched the copies already committed.

ol <- read.csv("data/processed/olympic_model_split.csv")
raw <- read.csv("data/processed/olympic_model.csv")

# Covers the whole 875 rather than the training rows alone. There are only 26
# failures, so splitting them again leaves cells of one or two venues in the
# tables below. The models were still fitted on the training rows only.

cat("Records pulled:", nrow(raw), "\n")
# Records pulled: 983
cat("Temporary, outcome not coded:", sum(is.na(raw$white_elephant)), "\n")
# Temporary, outcome not coded: 108
cat("Analytical sample:", nrow(ol), "failures:", sum(ol$white_elephant),
    "rate (%):", round(100 * mean(ol$white_elephant), 1), "\n")
# Analytical sample: 875 failures: 26 rate (%): 3
cat("Train and test, by outcome\n")
print(table(ol$set, ol$white_elephant))
#         FALSE TRUE
#   test    299    9
#   train   550   17

# The July rule counted any venue not in use. The frozen rule counts only the
# ones abandoned before demolition, so redevelopment, replacement and war stop
# being failures.
old_rule <- sum(ol$status_group == "not in use")
new_rule <- sum(ol$white_elephant)
cat("Failures under the July rule:", old_rule, "under ours:", new_rule,
    "disagreeing:", old_rule - new_rule, "\n")
# Failures under the July rule: 106 under ours: 26 disagreeing: 80

png("reports/EDA/final/fig1_outcome_definition.png",
    width = 1800, height = 1100, res = 200)
barplot(100 * c(new_rule, old_rule) / nrow(ol),
        names.arg = c("Abandoned before demolition", "Any venue not in use"),
        main = "Figure 1. Failures counted under each outcome rule",
        xlab = "Outcome definition",
        ylab = "Venues counted as failures (%)")
dev.off()

# Missing values as they stood before imputation filled them. Reported for the
# whole sample and for the training rows, since the medians came from training.
miss <- c("log_capacity", "venue_age", "years_since_construction",
          "log_distance", "log_gdp", "gdp_pct_rank", "log_city_pop",
          "city_pop_pct_rank", "years_since_event", "new_build", "region")
train <- ol[ol$set == "train", ]

cat("Missing before imputation (%)\n")
print(data.frame(
                whole_sample = round(100 * colMeans(is.na(ol[, miss])), 1),
                training_rows = round(100 * colMeans(is.na(train[, miss])), 1)))
#                          whole_sample training_rows
# log_capacity                     84.5          83.8
# venue_age                        80.8          80.6
# years_since_construction         80.8          80.6
# log_distance                     77.4          77.4
# log_gdp                          38.2          39.0
# gdp_pct_rank                     38.2          39.0
# log_city_pop                     13.5          12.5
# city_pop_pct_rank                13.5          12.5
# years_since_event                 0.0           0.0
# new_build                         1.3           1.1
# region                            0.0           0.0

# Capacity is the column imputation changes most, so it gets a before and an
# after. Every filled row takes the same training median, which is why the
# second panel is one tall bar.
observed <- ol$log_capacity[!is.na(ol$log_capacity)]
filled <- ol$log_capacity_imp[is.na(ol$log_capacity)][1]
cat("Capacity observed for", length(observed), "of", nrow(ol),
    "venues, the rest filled with", round(filled, 2),
    "which is about", round(exp(filled)), "seats\n")
# Capacity observed for 136 of 875 venues, the rest filled with 9.63 which is
# about 15200 seats
cat("Observed capacity runs from", round(exp(min(observed))), "to",
    round(exp(max(observed))), "seats\n")
# Observed capacity runs from 101 to 92747 seats
cat("Capacity spread, observed only:", round(sd(observed), 2),
    "after imputation:", round(sd(ol$log_capacity_imp), 2), "\n")
# Capacity spread, observed only: 1.14 after imputation: 0.45

png("reports/EDA/final/fig2_capacity_imputation.png",
    width = 1800, height = 1600, res = 200)
par(mfrow = c(2, 1))
hist(observed, breaks = 20,
     main = "Figure 2a. Capacity before imputation, 136 observed venues",
     xlab = "Log seating capacity", ylab = "Venues")
hist(ol$log_capacity_imp, breaks = 20,
     main = "Figure 2b. Capacity after imputation, all 875 venues",
     xlab = "Log seating capacity", ylab = "Venues")
dev.off()

# Failure rate by each of the three predictors that can be read straight off
# the data. Counts come first because the rates rest on very few failures.
ol$build_type <- ifelse(ol$new_build == 1, "Built for the Games",
                        "Already existed")
ol$era_label <- ol$era
ol$era_label[ol$era == "pre-WWII"] <- "1896-1936"
ol$era_label[ol$era == "postwar"] <- "1948-2000"
ol$era_label[ol$era == "recent"] <- "2002-2022"

cat("Venues and failures by build type\n")
print(table(ol$build_type, ol$white_elephant))
#                       FALSE TRUE
#   Already existed       459   11
#   Built for the Games   379   15
cat("Venues and failures by region\n")
print(table(ol$region, ol$white_elephant))
#            FALSE TRUE
#   Americas   190    5
#   Asia       176    3
#   Europe     436   18
#   Oceania     47    0
cat("Venues and failures by era\n")
print(table(ol$era_label, ol$white_elephant))
#             FALSE TRUE
#   1896-1936   132    7
#   1948-2000   495   10
#   2002-2022   222    9

# Eleven venues are classified temporary but were not dismantled, so they have
# no build type. aggregate drops them, which is why the build-type figure
# covers 864 venues rather than 875.
build <- aggregate(white_elephant ~ build_type, data = ol, FUN = mean)
region <- aggregate(white_elephant ~ region, data = ol, FUN = mean)
era <- aggregate(white_elephant ~ era_label, data = ol, FUN = mean)

cat("Failure rate by build type (%)\n")
print(round(100 * build$white_elephant, 1))
# [1] 2.3 3.8
cat("Failure rate by region (%)\n")
print(round(100 * region$white_elephant, 1))
# [1] 2.6 1.7 4.0 0.0
cat("Failure rate by era (%)\n")
print(round(100 * era$white_elephant, 1))
# [1] 5.0 2.0 3.9

png("reports/EDA/final/fig3_rate_by_build_type.png",
    width = 1800, height = 1100, res = 200)
barplot(100 * build$white_elephant, names.arg = build$build_type,
        main = "Figure 3. Failure rate by whether the venue was built new",
        xlab = "Venue type", ylab = "Venues abandoned (%)")
dev.off()

png("reports/EDA/final/fig4_rate_by_region.png",
    width = 1800, height = 1100, res = 200)
barplot(100 * region$white_elephant, names.arg = region$region,
        main = "Figure 4. Failure rate by region of the host city",
        xlab = "Region", ylab = "Venues abandoned (%)")
dev.off()

png("reports/EDA/final/fig5_rate_by_era.png",
    width = 1800, height = 1100, res = 200)
barplot(100 * era$white_elephant, names.arg = era$era_label,
        main = "Figure 5. Failure rate by when the Games were held",
        xlab = "When the Games were held", ylab = "Venues abandoned (%)")
dev.off()

cat("Saved five figures to reports/EDA/final\n")
