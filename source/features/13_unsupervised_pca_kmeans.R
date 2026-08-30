# Author: JL
# PCA and k-means on the Olympic venues, fitted on the training rows only.
# The outcome was kept out of both and only used afterwards, to check whether
# the groups they found had anything to do with what we are trying to predict.

# Reran this from the repo root on 2026-08-30 and it ran without error. The
# variance shares came out the same as the ones pasted further down.

set.seed(123)

ol <- read.csv("data/processed/olympic_model_split.csv")
train <- ol[ol$set == "train", ]

# Used the imputed columns so no rows drop out. Left out the _z and _pct_rank
# versions, which are rescalings of columns already in the list.
feat <- c("log_capacity_imp", "log_gdp_imp", "log_city_pop_imp",
          "log_distance_imp", "venue_age_imp", "years_since_event_imp",
          "years_since_construction_imp")

train_feat <- train[, feat]

# Checked the three time features first. Years since construction should equal
# years since event plus venue age, and filling them separately with medians
# breaks that.
gap <- train$years_since_construction_imp -
  (train$years_since_event_imp + train$venue_age_imp)
cat("Rows where the three time features still add up:",
    sum(abs(gap) < 1e-8), "of", nrow(train), "\n")
# Rows where the three time features still add up: 110 of 567

# Scaled the inputs because they are in different units
# (log seats, log miles, years).
pca <- prcomp(train_feat, scale. = TRUE)
var.pct <- 100 * pca$sdev^2 / sum(pca$sdev^2)

cat("Variance explained by each component (%)\n")
print(round(var.pct, 1))
# [1] 26.1 19.9 16.4 14.2 10.9  9.0  3.5
cat("Running total (%)\n")
print(round(cumsum(var.pct), 1))
# [1]  26.1  46.0  62.4  76.6  87.5  96.5 100.0
cat("Loadings on the first three components\n")
print(round(pca$rotation[, 1:3], 2))
#                               PC1   PC2   PC3
# log_capacity_imp             0.34 -0.36 -0.13
# log_gdp_imp                  0.00 -0.18  0.77
# log_city_pop_imp             0.00 -0.36 -0.52
# log_distance_imp             0.34 -0.48 -0.11
# venue_age_imp                0.66  0.08  0.14
# years_since_event_imp        0.00  0.55 -0.28
# years_since_construction_imp 0.58  0.41 -0.01

# Ran k from 1 to 8 first, to pick the number of groups from the data.
train_scaled <- scale(train_feat)
wss <- numeric(8)
for (k in 1:8) {
  wss[k] <- kmeans(train_scaled, centers = k, nstart = 25)$tot.withinss
}
cat("Within-cluster sum of squares for k = 1 to 8\n")
print(round(wss, 1))
# [1] 3962.0 3191.8 2707.5 2339.6 1995.5 1741.5 1553.5 1436.5

# Took three groups to look at. There is no clear elbow above, so this is for
# inspection rather than a number the data pointed to.
km <- kmeans(train_scaled, centers = 3, nstart = 25)
train$cluster <- km$cluster

cat("Cluster sizes\n")
print(table(train$cluster))
#   1   2   3
#  25 236 306
cat("Unused venues in each cluster\n")
print(table(train$cluster, train$white_elephant))
#     FALSE TRUE
#   1    25    0
#   2   228    8
#   3   297    9
cat("Share of each cluster that is an unused venue\n")
print(round(aggregate(white_elephant ~ cluster, data = train, FUN = mean), 3))
#   cluster white_elephant
# 1       1          0.000
# 2       2          0.034
# 3       3          0.029
# All three groups sit near the 3% base rate, so which cluster a venue lands
# in doesn't say much about whether it goes unused. The cluster numbers get
# shuffled between runs, so only the grouping is stable, not the labels.
cat("Cluster averages on the original features\n")
print(round(aggregate(train[, feat], by = list(cluster = train$cluster),
                      FUN = mean), 2))
#   cluster log_capacity_imp log_gdp_imp log_city_pop_imp log_distance_imp
# 1       1            10.03        9.12             7.46             2.84
# 2       2             9.59        9.67             7.88             1.96
# 3       3             9.60        8.49             7.87             1.93
#   venue_age_imp years_since_event_imp years_since_construction_imp
# 1         47.08                 41.44                        88.52
# 2          6.61                 24.01                        38.22
# 3          6.42                 71.31                        43.21

# Dropped the cluster scatter we first drew because the groups overlap heavily
# and the tables above make the same point.
png("reports/cleaning_preprocessing/figs/fig1_pca_scree.png",
    width = 1800, height = 1100, res = 200)
barplot(var.pct,
        names.arg = paste0("PC", 1:7),
        main = "Figure 6. Variance explained by each principal component",
        xlab = "Principal component",
        ylab = "Share of variance explained (%)")
dev.off()

cat("Saved fig1_pca_scree.png\n")
