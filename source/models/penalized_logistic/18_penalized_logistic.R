# Author: MG
# Sprint 6: penalized logistic regression (elastic net via glmnet), Olympic
# and World Cup. Final predictor set: log_capacity_imp, gdp_pct_rank_imp,
# city_pop_pct_rank_imp, new_build, region. Tunes alpha (ridge/LASSO
# balance) and lambda (penalty strength).

# CV folds are grouped by Olympics edition (games_year + host_city) so no
# edition splits across train and validation within a fold, since venues
# from the same edition share identical GDP and city population. Fold
# assignment also balances failure counts across folds.

library(tidyverse)
library(caret)
library(glmnet)
library(pROC)

set.seed(123)

predictors <- c("log_capacity_imp", "gdp_pct_rank_imp", "city_pop_pct_rank_imp",
                "new_build", "region")

# Builds train-set row indices for a grouped, repeated k-fold CV. Every row
# from the same edition_id stays in one fold. Editions go to whichever fold
# currently has the fewest failures, so failures spread as evenly across
# folds as the grouping allows.
make_grouped_folds <- function(edition_id, y, k = 5, repeats = 10, seed = 123) {
  set.seed(seed)
  index <- list()
  for (r in seq_len(repeats)) {
    editions <- unique(edition_id)
    edition_order <- sample(editions)
    fold_fail_count <- rep(0, k)
    fold_row_count <- rep(0, k)
    fold_of <- setNames(rep(NA_integer_, length(editions)), editions)
    
    for (ed in edition_order) {
      rows <- which(edition_id == ed)
      n_fail <- sum(y[rows] == "yes")
      pick <- order(fold_fail_count, fold_row_count)[1]
      fold_of[ed] <- pick
      fold_fail_count[pick] <- fold_fail_count[pick] + n_fail
      fold_row_count[pick] <- fold_row_count[pick] + length(rows)
    }
    
    row_fold <- fold_of[edition_id]
    for (f in seq_len(k)) {
      index[[paste0("Fold", f, ".Rep", r)]] <- which(row_fold != f)
    }
  }
  index
}

# ---- Olympic: CV-scored ----
ol <- read_csv("data/processed/olympic_model_split.csv", show_col_types = FALSE) |>
  mutate(white_elephant = factor(if_else(white_elephant, "yes", "no"),
                                 levels = c("no", "yes")),
         new_build = factor(new_build),
         region = factor(region),
         edition_id = paste(games_year, host_city))

ol_train <- ol |> filter(set == "train") |>
  select(white_elephant, all_of(predictors), edition_id) |> drop_na()

cat("Olympic training rows used:", nrow(ol_train),
    "| failures:", sum(ol_train$white_elephant == "yes"),
    "| unique editions:", n_distinct(ol_train$edition_id), "\n")

grouped_index <- make_grouped_folds(ol_train$edition_id, ol_train$white_elephant,
                                    k = 5, repeats = 10, seed = 123)

cat("Failures per fold, repeat 1 (checking the balance):\n")
fold_check <- sapply(1:5, function(f) {
  held_out <- setdiff(seq_len(nrow(ol_train)), grouped_index[[paste0("Fold", f, ".Rep1")]])
  sum(ol_train$white_elephant[held_out] == "yes")
})
print(fold_check)

# method = "cv" since the index list below already encodes all 5 folds x 10
# repeats; caret uses the supplied index directly instead of generating folds.
ctrl <- trainControl(method = "cv", classProbs = TRUE,
                     summaryFunction = twoClassSummary, savePredictions = "final",
                     index = grouped_index)

tune_grid <- expand.grid(alpha = seq(0, 1, by = 0.1),
                         lambda = 10^seq(-4, 1, length.out = 30))

fit_glmnet <- train(white_elephant ~ . - edition_id, data = ol_train, method = "glmnet",
                    trControl = ctrl, tuneGrid = tune_grid, metric = "ROC")

cat("\n== Olympic: Elastic net (glmnet), grouped CV, 5-fold x 10 repeats ==\n")
cat("Best alpha:", fit_glmnet$bestTune$alpha,
    "| best lambda:", round(fit_glmnet$bestTune$lambda, 5), "\n")
print(fit_glmnet$results |>
        filter(alpha == fit_glmnet$bestTune$alpha,
               lambda == fit_glmnet$bestTune$lambda))

cat("\nElastic net ROC across the 50 folds: min", round(min(fit_glmnet$resample$ROC), 3),
    "max", round(max(fit_glmnet$resample$ROC), 3),
    "mean", round(mean(fit_glmnet$resample$ROC), 3), "\n")

best_cut <- function(pred_df) {
  roc_obj <- roc(pred_df$obs, pred_df$yes, levels = c("no", "yes"),
                 direction = "<", quiet = TRUE)
  coords(roc_obj, "best", best.method = "youden",
         ret = c("threshold", "sensitivity", "specificity"))
}

glmnet_cut <- best_cut(fit_glmnet$pred)
cat("\nElastic net, Youden-optimal cutoff:", round(glmnet_cut$threshold, 3), "\n")
fit_glmnet$pred$pred_yj <- factor(if_else(fit_glmnet$pred$yes >= glmnet_cut$threshold, "yes", "no"),
                                  levels = c("no", "yes"))
print(confusionMatrix(fit_glmnet$pred$pred_yj, fit_glmnet$pred$obs, positive = "yes"))

cat("\nCoefficients at the best alpha/lambda:\n")
print(coef(fit_glmnet$finalModel, s = fit_glmnet$bestTune$lambda))

cat("\n== AUC comparison ==\n")
cat("Logistic regression (S5 baseline, ungrouped CV): 0.586\n")
cat("LDA (S5 baseline, ungrouped CV):                 0.597\n")
cat("Elastic net (grouped CV, this script):           ", round(mean(fit_glmnet$resample$ROC), 3), "\n")

roc_glmnet <- roc(fit_glmnet$pred$obs, fit_glmnet$pred$yes,
                  levels = c("no", "yes"), direction = "<", quiet = TRUE)

png("reports/modeling/figs/penalized_logistic_roc_curve.png", width = 1600, height = 1400, res = 200)
plot(roc_glmnet, col = "#276749", lwd = 2,
     main = "Elastic Net ROC Curve, Olympic Data (Grouped CV, Pooled Out-of-Fold Predictions)")
abline(a = 1, b = -1, lty = 2, col = "gray60")
legend("bottomright",
       legend = c(sprintf("Elastic net (mean CV AUC = %.3f)", mean(fit_glmnet$resample$ROC)),
                  "Chance"),
       col = c("#276749", "gray60"), lwd = c(2, 1), lty = c(1, 2))
dev.off()
cat("\nSaved penalized_logistic_roc_curve.png to the repo root.\n")

# ---- World Cup: descriptive only, not CV-scored ----
wc <- read_csv("data/processed/worldcup_model_split.csv", show_col_types = FALSE) |>
  mutate(white_elephant = factor(if_else(white_elephant, "yes", "no"), levels = c("no", "yes")),
         new_build = factor(new_build),
         region = factor(region))

wc_all <- wc |> select(white_elephant, all_of(predictors)) |> drop_na()
cat("\nWorld Cup rows used:", nrow(wc_all),
    "| failures:", sum(wc_all$white_elephant == "yes"), "\n")

wc_logit <- glm(white_elephant ~ ., data = wc_all, family = "binomial")
cat("== World Cup: logistic regression with the final predictor set (descriptive only) ==\n")
print(summary(wc_logit))