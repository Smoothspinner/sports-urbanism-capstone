# Author: JL
# PCA and k-means on the Olympic venues, fitted on the training rows only.
# The outcome was kept out of both and only used afterwards, to check whether the groups they found had anything to do with what we are trying to predict.

set.seed(123)

ol <- read.csv("data/processed/olympic_model_split.csv")
train <- ol[ol$set == "train", ]

# Used the imputed columns so no rows drop out. Left out the _z and _pct_rank versions, which are rescalings of columns already in the list.
feat <- c("log_capacity_imp", "log_gdp_imp", "log_city_pop_imp",
          "log_distance_imp", "venue_age_imp", "years_since_event_imp",
          "years_since_construction_imp")

train_feat <- train[, feat]

# Checked the three time features first. Years since construction should equal years since event plus venue age, and filling them separately with medians breaks that.
gap <- train$years_since_construction_imp -
  (train$years_since_event_imp + train$venue_age_imp)
cat("Rows where the three time features still add up:",
    sum(abs(gap) < 1e-8), "of", nrow(train), "\n")
# Rows where the three time features still add up: 126 of 572

# Scaled the inputs because they are in different units (log seats, log miles, years).
pca <- prcomp(train_feat, scale. = TRUE)
var.pct <- 100 * pca$sdev^2 / sum(pca$sdev^2)

cat("Variance explained by each component (%)\n")
print(round(var.pct, 1))
# [1] 27.4 19.8 16.5 13.8 10.6  8.8  3.0
cat("Running total (%)\n")
print(round(cumsum(var.pct), 1))
# [1]  27.4  47.2  63.8  77.6  88.2  97.0 100.0
cat("Loadings on the first three components\n")
print(round(pca$rotation[, 1:3], 2))
#                                PC1   PC2   PC3
# log_capacity_imp             -0.39 -0.30 -0.18
# log_gdp_imp                  -0.06 -0.26  0.73
# log_city_pop_imp              0.03 -0.28 -0.59
# log_distance_imp             -0.31 -0.51 -0.18
# venue_age_imp                -0.65  0.05  0.09
# years_since_event_imp        -0.05  0.60 -0.21
# years_since_construction_imp -0.58  0.37  0.01

# Ran k from 1 to 8 first, to pick the number of groups from the data.
train_scaled <- scale(train_feat)
wss <- numeric(8)
for (k in 1:8) {
  wss[k] <- kmeans(train_scaled, centers = k, nstart = 25)$tot.withinss
}
cat("Within-cluster sum of squares for k = 1 to 8\n")
print(round(wss, 1))
# [1] 3997.0 3175.9 2679.5 2309.6 1979.0 1710.8 1512.5 1375.0

# Took three groups to look at. There is no clear elbow above, so this is for inspection rather than a number the data pointed to.
km <- kmeans(train_scaled, centers = 3, nstart = 25)
train$cluster <- km$cluster

cat("Cluster sizes\n")
print(table(train$cluster))
#   1   2   3
# 348 202  22
cat("Unused venues in each cluster\n")
print(table(train$cluster, train$white_elephant))
#     FALSE TRUE
#   1   299   49
#   2   186   16
#   3    18    4
cat("Share of each cluster that is an unused venue\n")
print(round(aggregate(white_elephant ~ cluster, data = train, FUN = mean), 3))
#   cluster white_elephant
# 1       1          0.141
# 2       2          0.079
# 3       3          0.182
cat("Cluster averages on the original features\n")
print(round(aggregate(train[, feat], by = list(cluster = train$cluster),
                      FUN = mean), 2))
#   cluster log_capacity_imp log_gdp_imp log_city_pop_imp log_distance_imp
# 1       1             9.62        8.54             7.85             2.04
# 2       2             9.53        9.81             7.78             2.10
# 3       3            10.08        9.32             7.52             2.82
#   venue_age_imp years_since_event_imp years_since_construction_imp
# 1          5.26                 66.90                        40.57
# 2          5.27                 20.04                        35.04
# 3         48.55                 52.45                       101.00

# Dropped the cluster scatter we first drew because the groups overlap heavily and the tables above make the same point.
png("reports/cleaning_preprocessing/figs/fig1_pca_scree.png",
    width = 1800, height = 1100, res = 200)
barplot(var.pct,
        names.arg = paste0("PC", 1:7),
        main = "Figure 1. Variance explained by each principal component",
        xlab = "Principal component",
        ylab = "Share of variance explained (%)")
dev.off()

cat("Saved fig1_pca_scree.png\n")
