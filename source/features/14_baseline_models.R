# Author: MG
# Baseline classifiers: logistic regression and LDA, Olympic only.
# Scored with repeated stratified k-fold CV (a range, not one train/test
# number) per Katie's feedback on the last report.

# Kept to 4 predictors: with only ~17 failures in the training fold, more
# than a handful risks badly overfitting (rule of thumb is ~10 events per
# predictor). World Cup has just 3 distinct failed stadiums total, too few
# to fold or score at all, so it's fit and described below but not CV-scored.

# Uses caret (cross-validation), pROC, and MASS (pulled in by caret for LDA).

library(tidyverse)
library(caret)
library(pROC)

set.seed(123)

predictors <- c("log_capacity_imp", "gdp_pct_rank_imp", "city_pop_pct_rank_imp", "new_build")

# ---- Olympic: CV-scored ----
ol <- read_csv("data/processed/olympic_model_split.csv", show_col_types = FALSE) |>
  mutate(white_elephant = factor(if_else(white_elephant, "yes", "no"),
                                 levels = c("no", "yes")),
         new_build = factor(new_build))

ol_train <- ol |> filter(set == "train") |>
  select(white_elephant, all_of(predictors)) |> drop_na()

cat("Olympic training rows used:", nrow(ol_train),
    "| failures:", sum(ol_train$white_elephant == "yes"), "\n\n")

ctrl <- trainControl(method = "repeatedcv", number = 5, repeats = 10,
                     classProbs = TRUE, summaryFunction = twoClassSummary,
                     savePredictions = "final")

fit_logit <- train(white_elephant ~ ., data = ol_train, method = "glm",
                   family = "binomial", trControl = ctrl, metric = "ROC")
fit_lda <- train(white_elephant ~ ., data = ol_train, method = "lda",
                 trControl = ctrl, metric = "ROC")

cat("== Olympic: Logistic regression, 5-fold CV x 10 repeats ==\n")
print(fit_logit$results)
cat("\n== Olympic: LDA, 5-fold CV x 10 repeats ==\n")
print(fit_lda$results)

cat("\nLogistic ROC across the 50 folds: min", round(min(fit_logit$resample$ROC), 3),
    "max", round(max(fit_logit$resample$ROC), 3),
    "mean", round(mean(fit_logit$resample$ROC), 3), "\n")
cat("LDA ROC across the 50 folds: min", round(min(fit_lda$resample$ROC), 3),
    "max", round(max(fit_lda$resample$ROC), 3),
    "mean", round(mean(fit_lda$resample$ROC), 3), "\n")

# Pooled out-of-fold probabilities re-cut at the threshold that balances
# sensitivity and specificity (Youden's J), instead of the default .5, since
# .5 calls almost everything "no" at a 3% failure rate.
best_cut <- function(pred_df) {
  roc_obj <- roc(pred_df$obs, pred_df$yes, levels = c("no", "yes"),
                 direction = "<", quiet = TRUE)
  coords(roc_obj, "best", best.method = "youden",
         ret = c("threshold", "sensitivity", "specificity"))
}

logit_cut <- best_cut(fit_logit$pred)
lda_cut   <- best_cut(fit_lda$pred)

cat("\nLogistic regression, Youden-optimal cutoff:", round(logit_cut$threshold, 3), "\n")
fit_logit$pred$pred_yj <- factor(if_else(fit_logit$pred$yes >= logit_cut$threshold, "yes", "no"),
                                 levels = c("no", "yes"))
print(confusionMatrix(fit_logit$pred$pred_yj, fit_logit$pred$obs, positive = "yes"))

cat("\nLDA, Youden-optimal cutoff:", round(lda_cut$threshold, 3), "\n")
fit_lda$pred$pred_yj <- factor(if_else(fit_lda$pred$yes >= lda_cut$threshold, "yes", "no"),
                               levels = c("no", "yes"))
print(confusionMatrix(fit_lda$pred$pred_yj, fit_lda$pred$obs, positive = "yes"))

# ---- World Cup: descriptive only, not CV-scored ----
wc <- read_csv("data/processed/worldcup_model_split.csv", show_col_types = FALSE) |>
  mutate(white_elephant = factor(if_else(white_elephant, "yes", "no"),
                                 levels = c("no", "yes")),
         new_build = factor(new_build))

wc_all <- wc |> select(white_elephant, all_of(predictors)) |> drop_na()

cat("\nWorld Cup rows used:", nrow(wc_all),
    "| failures:", sum(wc_all$white_elephant == "yes"), "\n\n")

wc_logit <- glm(white_elephant ~ ., data = wc_all, family = "binomial")
cat("== World Cup: Logistic regression, fit on all rows (descriptive only) ==\n")
print(summary(wc_logit))

cat("\nWorld Cup new_build vs failure crosstab (explains the huge new_build1 SE above):\n")
print(table(wc_all$new_build, wc_all$white_elephant))