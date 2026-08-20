# Author: MG
# Sprint 6 diagnostic: does dropping log_capacity for region cost real
# signal, or does the penalty shrink capacity toward zero anyway? Same
# elastic net setup as 16_penalized_logistic.R, predictor set adds
# log_capacity_imp back in alongside region instead of swapping it out.

library(tidyverse)
library(caret)
library(glmnet)
library(pROC)

set.seed(123)

predictors <- c("log_capacity_imp", "gdp_pct_rank_imp", "city_pop_pct_rank_imp",
                "new_build", "region")

ol <- read_csv("data/processed/olympic_model_split.csv", show_col_types = FALSE) |>
  mutate(white_elephant = factor(if_else(white_elephant, "yes", "no"),
                                 levels = c("no", "yes")),
         new_build = factor(new_build),
         region = factor(region))

ol_train <- ol |> filter(set == "train") |>
  select(white_elephant, all_of(predictors)) |> drop_na()

cat("Olympic training rows used:", nrow(ol_train),
    "| failures:", sum(ol_train$white_elephant == "yes"), "\n")

ctrl <- trainControl(method = "repeatedcv", number = 5, repeats = 10,
                     classProbs = TRUE, summaryFunction = twoClassSummary,
                     savePredictions = "final")

tune_grid <- expand.grid(alpha = seq(0, 1, by = 0.1),
                         lambda = 10^seq(-4, 1, length.out = 30))

fit_5pred <- train(white_elephant ~ ., data = ol_train, method = "glmnet",
                   trControl = ctrl, tuneGrid = tune_grid, metric = "ROC")

cat("\n== 5-predictor model (capacity + region), 5-fold CV x 10 repeats ==\n")
cat("Best alpha:", fit_5pred$bestTune$alpha,
    "| best lambda:", round(fit_5pred$bestTune$lambda, 5), "\n")
cat("Mean CV AUC:", round(mean(fit_5pred$resample$ROC), 3), "\n")

cat("\nCoefficients at the best alpha/lambda:\n")
print(coef(fit_5pred$finalModel, s = fit_5pred$bestTune$lambda))

# ---- Comparison across all three ----
cat("\n== AUC comparison ==\n")
cat("Logistic regression (S5 baseline, capacity/GDP/pop/new-build): 0.586\n")
cat("LDA (S5 baseline, capacity/GDP/pop/new-build):                 0.597\n")
cat("Elastic net (S6, region swapped in for capacity):               0.554\n")
cat("Elastic net (this script, capacity AND region both included): ",
    round(mean(fit_5pred$resample$ROC), 3), "\n")