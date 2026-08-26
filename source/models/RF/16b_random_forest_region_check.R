# Author: JL
# Sprint 6 diagnostic: region was added to the random forest so all three S6
# models run on the same predictors. This checks what adding it cost. Script
# 16 changed the predictor set and the mtry grid at the same time (five
# predictors become seven columns, so the grid moved from 2/4 to 3/7), which
# means the drop in AUC there can't be pinned on region by itself.

# Same grouped folds and same rows as script 16. mtry is held at 2 and 4 for
# both predictor sets, so the only thing changing between the two rows is
# whether region is in the model.

library(randomForest)
library(caret)
library(pROC)

set.seed(123)

four <- c("log_capacity_imp", "gdp_pct_rank_imp", "city_pop_pct_rank_imp",
          "new_build")
five <- c(four, "region")

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
ol$region <- as.factor(ol$region)
ol$edition_id <- paste(ol$games_year, ol$host_city)

# Rows are taken on the five-predictor set for both fits, so a row dropped
# for a missing region isn't in one model and out of the other. Region has
# no missing values, so this doesn't actually drop anything, but it keeps
# the two fits on identical rows without relying on that.
ol_train <- na.omit(ol[ol$set == "train",
                       c("white_elephant", five, "edition_id")])

cat("Training rows:", nrow(ol_train), "failures:",
    sum(ol_train$white_elephant == "yes"), "\n")

grouped_index <- make_grouped_folds(ol_train$edition_id,
                                    ol_train$white_elephant,
                                    k = 5, repeats = 10, seed = 123)

ctrl <- trainControl(method = "cv", classProbs = TRUE,
                     summaryFunction = twoClassSummary, index = grouped_index)

tune_grid <- data.frame(mtry = c(2, 4))

# Seeded again immediately before each fit rather than once at the top. A
# forest uses random numbers while it builds, so without a fresh seed here
# the second fit picks up wherever the first one left off, and the two
# models end up differing by more than just the predictor set. Worth
# keeping: without these two lines the four-predictor numbers move by about
# 0.02 between runs depending on what was fitted before them.
set.seed(123)
fit_four <- train(white_elephant ~ .,
                  data = ol_train[, c("white_elephant", four)],
                  method = "rf", trControl = ctrl, tuneGrid = tune_grid,
                  metric = "ROC")

set.seed(123)
fit_five <- train(white_elephant ~ .,
                  data = ol_train[, c("white_elephant", five)],
                  method = "rf", trControl = ctrl, tuneGrid = tune_grid,
                  metric = "ROC")

cat("\nFour predictors, no region:\n")
print(fit_four$results[, c("mtry", "ROC", "ROCSD")])

cat("\nFive predictors, region added:\n")
print(fit_five$results[, c("mtry", "ROC", "ROCSD")])

cat("\nCost of adding region, at each mtry:\n")
print(data.frame(mtry = fit_four$results$mtry,
                 four = round(fit_four$results$ROC, 4),
                 five = round(fit_five$results$ROC, 4),
                 diff = round(fit_five$results$ROC - fit_four$results$ROC, 4)))
