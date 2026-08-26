# Author: BW
# Sprint 6, Item 5: threshold-as-a-range reporting.
#
# Run this AFTER:
#   source("source/models/penalized_logistic/18_penalized_logistic.R")
#   source("source/models/RF/16_random_forest.R")
#   source("source/models/GBM/17_gradient_boosting.R")
#
# All three models must use the grouped Olympic-edition CV before this script is run.
# This script evaluates the saved out-of-fold probabilities from those grouped
# folds. It does NOT choose a single "best" threshold from the final test set.

library(tidyverse)

if (!exists("fit_glmnet")) {
  stop("fit_glmnet not found. Run 18_penalized_logistic.R first.")
}
if (!exists("fit_rf")) {
  stop("fit_rf not found. Run 16_random_forest.R first.")
}
if (!exists("fit_gbm")) {
  stop("fit_gbm not found. Run 17_gradient_boosting.R first.")
}

# Keep only predictions for the selected tuning parameters if caret stored more
# than one tuning combination.
best_oof_predictions <- function(fit) {
  pred <- fit$pred
  
  if ("alpha" %in% names(pred) && "alpha" %in% names(fit$bestTune)) {
    pred <- pred |> filter(alpha == fit$bestTune$alpha)
  }
  if ("lambda" %in% names(pred) && "lambda" %in% names(fit$bestTune)) {
    pred <- pred |> filter(abs(lambda - fit$bestTune$lambda) < 1e-12)
  }
  if ("mtry" %in% names(pred) && "mtry" %in% names(fit$bestTune)) {
    pred <- pred |> filter(mtry == fit$bestTune$mtry)
  }
  
  pred
}

# Calculate classification metrics at one threshold.
threshold_metrics <- function(obs, prob_yes, threshold) {
  pred_yes <- prob_yes >= threshold
  
  actual_yes <- obs == "yes"
  actual_no  <- obs == "no"
  
  tp <- sum(pred_yes & actual_yes, na.rm = TRUE)
  fp <- sum(pred_yes & actual_no,  na.rm = TRUE)
  tn <- sum(!pred_yes & actual_no, na.rm = TRUE)
  fn <- sum(!pred_yes & actual_yes, na.rm = TRUE)
  
  safe_div <- function(a, b) ifelse(b == 0, NA_real_, a / b)
  
  sensitivity <- safe_div(tp, tp + fn)
  specificity <- safe_div(tn, tn + fp)
  precision   <- safe_div(tp, tp + fp)
  f1          <- ifelse(
    is.na(precision) || is.na(sensitivity) ||
      (precision + sensitivity) == 0,
    NA_real_,
    2 * precision * sensitivity / (precision + sensitivity)
  )
  
  tibble(
    threshold = threshold,
    sensitivity = sensitivity,
    specificity = specificity,
    precision = precision,
    f1 = f1,
    balanced_accuracy = mean(c(sensitivity, specificity), na.rm = TRUE),
    predicted_positive_n = tp + fp,
    predicted_positive_rate = safe_div(tp + fp, tp + fp + tn + fn),
    true_positive = tp,
    false_positive = fp,
    true_negative = tn,
    false_negative = fn
  )
}

# Fine resolution around the observed event rate (~3%), then wider cutoffs.
# This is deliberately a REPORTING range, not a search for one test-set-optimal
# cutoff.
threshold_grid <- c(
  seq(0.005, 0.10, by = 0.005),
  0.125, 0.15, 0.20, 0.25, 0.30, 0.40, 0.50
)

make_threshold_report <- function(fit, model_name) {
  pred <- best_oof_predictions(fit)
  
  if (!all(c("obs", "yes") %in% names(pred))) {
    stop(paste(model_name, "does not contain caret OOF columns 'obs' and 'yes'."))
  }
  
  map_dfr(
    threshold_grid,
    ~ threshold_metrics(pred$obs, pred$yes, .x)
  ) |>
    mutate(model = model_name, .before = 1)
}

glmnet_pred <- best_oof_predictions(fit_glmnet)
rf_pred     <- best_oof_predictions(fit_rf)
gbm_pred    <- best_oof_predictions(fit_gbm)

probability_summary <- bind_rows(
  tibble(
    model = "Penalized logistic regression",
    n_oof_predictions = nrow(glmnet_pred),
    min = min(glmnet_pred$yes, na.rm = TRUE),
    p05 = quantile(glmnet_pred$yes, 0.05, na.rm = TRUE),
    median = median(glmnet_pred$yes, na.rm = TRUE),
    p95 = quantile(glmnet_pred$yes, 0.95, na.rm = TRUE),
    max = max(glmnet_pred$yes, na.rm = TRUE),
    sd = sd(glmnet_pred$yes, na.rm = TRUE)
  ),
  tibble(
    model = "Random forest",
    n_oof_predictions = nrow(rf_pred),
    min = min(rf_pred$yes, na.rm = TRUE),
    p05 = quantile(rf_pred$yes, 0.05, na.rm = TRUE),
    median = median(rf_pred$yes, na.rm = TRUE),
    p95 = quantile(rf_pred$yes, 0.95, na.rm = TRUE),
    max = max(rf_pred$yes, na.rm = TRUE),
    sd = sd(rf_pred$yes, na.rm = TRUE)
  ),
  tibble(
    model = "Gradient boosting",
    n_oof_predictions = nrow(gbm_pred),
    min = min(gbm_pred$yes, na.rm = TRUE),
    p05 = quantile(gbm_pred$yes, 0.05, na.rm = TRUE),
    median = median(gbm_pred$yes, na.rm = TRUE),
    p95 = quantile(gbm_pred$yes, 0.95, na.rm = TRUE),
    max = max(gbm_pred$yes, na.rm = TRUE),
    sd = sd(gbm_pred$yes, na.rm = TRUE)
  )
)

threshold_results <- bind_rows(
  make_threshold_report(fit_glmnet, "Penalized logistic regression"),
  make_threshold_report(fit_rf, "Random forest"),
  make_threshold_report(fit_gbm, "Gradient boosting")
)

cat("\n== OOF probability summaries ==\n")
print(probability_summary)

cat("\n== Threshold-as-a-range results ==\n")
print(
  threshold_results |>
    select(model, threshold, sensitivity, specificity, precision, f1,
           predicted_positive_n, predicted_positive_rate),
  n = Inf
)

# Save tables for the report.
dir.create("reports/modeling/tables", recursive = TRUE, showWarnings = FALSE)
write_csv(
  probability_summary,
  "reports/modeling/tables/threshold_probability_summary.csv"
)
write_csv(
  threshold_results,
  "reports/modeling/tables/threshold_range_results.csv"
)

# Plot the metrics across thresholds.
plot_data <- threshold_results |>
  select(model, threshold, sensitivity, specificity, precision, f1) |>
  pivot_longer(
    cols = c(sensitivity, specificity, precision, f1),
    names_to = "metric",
    values_to = "value"
  )

p <- ggplot(plot_data, aes(x = threshold, y = value, linetype = metric)) +
  geom_line(linewidth = 0.8, na.rm = TRUE) +
  geom_point(size = 1.5, na.rm = TRUE) +
  facet_wrap(~ model, scales = "free_x") +
  scale_y_continuous(limits = c(0, 1)) +
  labs(
    title = "Olympic White-Elephant Classification Across Probability Thresholds",
    subtitle = "Grouped Olympic-edition out-of-fold predictions",
    x = "Probability threshold",
    y = "Metric value",
    linetype = "Metric"
  ) +
  theme_minimal()

ggsave(
  "reports/modeling/figs/fig_threshold_range_metrics.png",
  p,
  width = 9,
  height = 6,
  dpi = 300
)

cat("\nSaved:\n")
cat("  reports/modeling/tables/threshold_probability_summary.csv\n")
cat("  reports/modeling/tables/threshold_range_results.csv\n")
cat("  reports/modeling/figs/fig_threshold_range_metrics.png\n")