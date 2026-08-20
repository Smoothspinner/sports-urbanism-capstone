# Author: JL
# Random forest, the additional tunable model for S6, Olympic only. World
# Cup has only 3 failed stadiums total, same reason script 14 (the baseline
# logistic regression / LDA models) never scored the World Cup side, so it's
# not repeated here.

# Compared bagging (mtry = 4, every predictor available at each split)
# against a smaller mtry (2, the rounded default for four predictors), to
# see whether restricting the split candidates changed anything on this
# data. Same 4 predictors as the baseline models.

# CV folds are grouped by Olympics edition (games_year + host_city) so no
# edition splits across train and validation within a fold, since venues
# from the same edition share identical GDP and city population. Fold
# assignment also balances failure counts across folds.

# The make_grouped_folds function below was written by MG and shared with
# the team after Katie's feedback, so all three of our models fold the same
# way. Dropped the earlier single train/test accuracy check, since the
# train/test split is grouped by venue and not by Games edition, so the
# test set has the same shared-GDP problem the folds just fixed.

library(randomForest)
library(caret)
library(pROC)

set.seed(123)

predictors <- c("log_capacity_imp", "gdp_pct_rank_imp",
                "city_pop_pct_rank_imp", "new_build")

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

ol <- read.csv("data/processed/olympic_model_split.csv")
ol$white_elephant <- as.factor(ifelse(ol$white_elephant, "yes", "no"))
ol$new_build <- as.factor(ol$new_build)
ol$edition_id <- paste(ol$games_year, ol$host_city)

ol_train <- na.omit(ol[ol$set == "train", c("white_elephant", predictors, "edition_id")])

cat("Training rows:", nrow(ol_train), "failures:",
    sum(ol_train$white_elephant == "yes"), "unique editions:",
    length(unique(ol_train$edition_id)), "\n")

grouped_index <- make_grouped_folds(ol_train$edition_id, ol_train$white_elephant,
                                    k = 5, repeats = 10, seed = 123)

cat("Failures per fold, repeat 1 (checking the balance):\n")
fold_check <- sapply(1:5, function(f) {
  held_out <- setdiff(seq_len(nrow(ol_train)), grouped_index[[paste0("Fold", f, ".Rep1")]])
  sum(ol_train$white_elephant[held_out] == "yes")
})
print(fold_check)

ctrl <- trainControl(method = "cv", classProbs = TRUE,
                     summaryFunction = twoClassSummary, savePredictions = "final",
                     index = grouped_index)

tune_grid <- data.frame(mtry = c(2, 4))

fit_rf <- train(white_elephant ~ . - edition_id, data = ol_train, method = "rf",
                trControl = ctrl, tuneGrid = tune_grid, metric = "ROC",
                importance = TRUE)

cat("Cross-validated results, mtry = 2 (random forest) vs mtry = 4 (bagging)\n")
print(fit_rf$results)

cat("Variable importance, best mtry from CV\n")
importance(fit_rf$finalModel)

png("reports/modeling/figs/fig1_rf_importance.png",
    width = 900, height = 600)
varImpPlot(fit_rf$finalModel, main = "Random forest variable importance")
dev.off()
