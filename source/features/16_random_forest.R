# Author: JL
# Random forest, the additional tunable model for S6, Olympic only. World
# Cup has only 3 failed stadiums total, same reason script 14 (the baseline
# logistic regression / LDA models) never scored the World Cup side, so it's
# not repeated here.

# Compared bagging (mtry = 4, every predictor available at each split)
# against a smaller mtry (2, the rounded default for four predictors), to
# see whether restricting the split candidates changed anything on this
# data. Same 4 predictors and train/test split as the baseline models, so
# the results are comparable to logistic regression and LDA.

library(randomForest)

set.seed(123)

predictors <- c("log_capacity_imp", "gdp_pct_rank_imp",
                "city_pop_pct_rank_imp", "new_build")

ol <- read.csv("data/processed/olympic_model_split.csv")
ol$white_elephant <- as.factor(ifelse(ol$white_elephant, "yes", "no"))
ol$new_build <- as.factor(ol$new_build)

ol_train <- na.omit(ol[ol$set == "train", c("white_elephant", predictors)])
ol_test <- na.omit(ol[ol$set == "test", c("white_elephant", predictors)])

cat("Training rows:", nrow(ol_train), "failures:",
    sum(ol_train$white_elephant == "yes"), "\n")
cat("Test rows:", nrow(ol_test), "failures:",
    sum(ol_test$white_elephant == "yes"), "\n")

# Bagging
rf_bag <- randomForest(white_elephant ~ ., data = ol_train, mtry = 4,
                       importance = TRUE)
rf_bag

# Random forest
rf_default <- randomForest(white_elephant ~ ., data = ol_train, mtry = 2,
                           importance = TRUE)
rf_default

cat("Bagging (mtry = 4) on the test set\n")
pred_bag <- predict(rf_bag, ol_test)
table(pred_bag, ol_test$white_elephant)
mean(pred_bag == ol_test$white_elephant)

cat("Random forest (mtry = 2) on the test set\n")
pred_default <- predict(rf_default, ol_test)
table(pred_default, ol_test$white_elephant)
mean(pred_default == ol_test$white_elephant)

cat("Variable importance, random forest (mtry = 2)\n")
importance(rf_default)

png("reports/modeling/figs/fig1_rf_importance.png",
    width = 900, height = 600)
varImpPlot(rf_default, main = "Random forest variable importance")
dev.off()
