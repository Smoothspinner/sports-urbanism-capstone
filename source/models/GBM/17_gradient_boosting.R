# Author: BW
# Sprint 6: Gradient Boosting Model
# Uses the same grouped Olympic-edition cross-validation as the other S6 models.

library(tidyverse)
library(caret)
library(gbm)
library(pROC)

set.seed(123)

predictors <- c(
  "log_capacity_imp",
  "gdp_pct_rank_imp",
  "city_pop_pct_rank_imp",
  "new_build",
  "region"
)

# Keep every venue from the same Olympic edition in the same CV fold.
# The function also spreads failures across folds as evenly as possible.
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
      index[[paste0("Fold", f, ".Rep", r)]] <-
        which(row_fold != f)
    }
  }
  
  index
}

# Load Olympic modeling data.
ol <- read_csv(
  "data/processed/olympic_model_split.csv",
  show_col_types = FALSE
) |>
  mutate(
    white_elephant = factor(
      if_else(white_elephant, "yes", "no"),
      levels = c("no", "yes")
    ),
    new_build = factor(new_build),
    region = factor(region),
    edition_id = paste(games_year, host_city)
  )

# Use training observations only.
ol_train <- ol |>
  filter(set == "train") |>
  select(
    white_elephant,
    all_of(predictors),
    edition_id
  ) |>
  drop_na()

cat(
  "Olympic training rows used:", nrow(ol_train),
  "| failures:", sum(ol_train$white_elephant == "yes"),
  "| unique editions:", n_distinct(ol_train$edition_id),
  "\n"
)

# Create grouped folds.
grouped_index <- make_grouped_folds(
  ol_train$edition_id,
  ol_train$white_elephant,
  k = 5,
  repeats = 10,
  seed = 123
)

cat("Failures per fold, repeat 1:\n")

fold_check <- sapply(1:5, function(f) {
  
  held_out <- setdiff(
    seq_len(nrow(ol_train)),
    grouped_index[[paste0("Fold", f, ".Rep1")]]
  )
  
  sum(ol_train$white_elephant[held_out] == "yes")
})

print(fold_check)

# caret uses our grouped folds instead of creating random folds.
ctrl <- trainControl(
  method = "cv",
  classProbs = TRUE,
  summaryFunction = twoClassSummary,
  savePredictions = "final",
  index = grouped_index
)

# GBM tuning grid.
#
# n.trees: number of boosting trees
# interaction.depth: tree complexity/depth
# shrinkage: learning rate
# n.minobsinnode: minimum observations allowed in a terminal node
gbm_grid <- expand.grid(
  n.trees = c(50, 100, 250),
  interaction.depth = c(1, 2, 3),
  shrinkage = c(0.01, 0.05, 0.10),
  n.minobsinnode = 10
)

cat(
  "\nGBM tuning combinations:",
  nrow(gbm_grid),
  "\n"
)

fit_gbm <- train(
  white_elephant ~ . - edition_id,
  data = ol_train,
  method = "gbm",
  trControl = ctrl,
  tuneGrid = gbm_grid,
  metric = "ROC",
  verbose = FALSE
)

cat("\n== Gradient Boosting, grouped CV ==\n")

cat(
  "Best number of trees:", fit_gbm$bestTune$n.trees,
  "\nBest tree depth:", fit_gbm$bestTune$interaction.depth,
  "\nBest learning rate:", fit_gbm$bestTune$shrinkage,
  "\nMinimum node size:", fit_gbm$bestTune$n.minobsinnode,
  "\n"
)

cat("\nBest tuning result:\n")

print(
  fit_gbm$results |>
    filter(
      n.trees == fit_gbm$bestTune$n.trees,
      interaction.depth == fit_gbm$bestTune$interaction.depth,
      shrinkage == fit_gbm$bestTune$shrinkage,
      n.minobsinnode == fit_gbm$bestTune$n.minobsinnode
    )
)

cat(
  "\nGBM ROC across grouped CV folds:\n",
  "min =", round(min(fit_gbm$resample$ROC, na.rm = TRUE), 3),
  "| max =", round(max(fit_gbm$resample$ROC, na.rm = TRUE), 3),
  "| mean =", round(mean(fit_gbm$resample$ROC, na.rm = TRUE), 3),
  "| SD =", round(sd(fit_gbm$resample$ROC, na.rm = TRUE), 3),
  "\n"
)

cat("\nVariable importance:\n")
print(varImp(fit_gbm))