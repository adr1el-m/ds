# FOUR-MEMBER STUDY VERSION
# Run Parts 1, 2, 3, and 4 in order, in one R session.
# Or click Source to run the complete script.
# The README explains each member's role and how to study the four parts.
# Edit your city/path in Part 1; all results use the same methods and graph styles.

# ========================================================================
# PART 1 - MEMBER 1: IMPORT, CHECK, AND GROUP THE DATA
# Question: Do we have complete and usable nighttime readings?
# ========================================================================

# Change these two lines when repeating the analysis for another city.
city <- "Manila"
csv_path <- "~/Downloads/manila-2000-2025.csv"

# Install once: install.packages(c("dplyr", "sandwich"))
library(dplyr)
library(sandwich)

# Every city must use ERA5, Celsius, Philippine time, and the same dates.
# Include January 1, 2026 in the download to finish the last research night.
city_folder <- gsub(" ", "_", tolower(city))
output_folder <- file.path("outputs", paste0("simple_", city_folder))
graph_folder <- file.path(output_folder, "graphs_png")
dir.create(graph_folder, recursive = TRUE, showWarnings = FALSE)

# Read the metadata and check that the file uses Philippine time (UTC+8).
metadata <- read.csv(csv_path, nrows = 1)
stopifnot(metadata$utc_offset_seconds == 28800)

# Skip the three metadata lines to reach the hourly table.
weather <- read.csv(csv_path, skip = 3, check.names = FALSE,
                    na.strings = c("", "NA", "NaN", "null"))
stopifnot(ncol(weather) == 2)
stopifnot(grepl("temperature_2m", names(weather)[2]))
stopifnot(grepl("°C", names(weather)[2], fixed = TRUE))
names(weather) <- c("local_time", "temperature_c")

# Convert text to dates/times and numeric temperatures.
original_time <- weather$local_time
original_temperature <- weather$temperature_c
weather$local_time <- as.POSIXct(original_time,
                               format = "%Y-%m-%dT%H:%M", tz = "Asia/Manila")
weather$temperature_c <- as.numeric(as.character(original_temperature))

# Stop if a timestamp is invalid, repeated, or not a whole-hour reading.
stopifnot(!anyNA(weather$local_time))
stopifnot(!anyDuplicated(weather$local_time))
converted_time <- format(weather$local_time, "%Y-%m-%dT%H:%M", tz = "Asia/Manila")
stopifnot(all(converted_time == original_time))
minutes <- format(weather$local_time, "%M", tz = "Asia/Manila")
stopifnot(all(minutes == "00"))
valid_temperature <- is.na(original_temperature) | is.finite(weather$temperature_c)
stopifnot(all(valid_temperature))
weather <- weather[order(weather$local_time), ]

# A research night is 8 PM through 5 AM, including both endpoints.
weather$hour <- as.integer(format(weather$local_time, "%H", tz = "Asia/Manila"))
weather$night_date <- as.Date(weather$local_time, tz = "Asia/Manila")
weather$night_date <- weather$night_date - as.integer(weather$hour <= 5)

night_hours <- weather |>
  filter(hour >= 20 | hour <= 5,
         night_date >= as.Date("2000-01-01"),
         night_date <= as.Date("2025-12-31"))

nightly <- night_hours |>
  group_by(night_date) |>
  summarise(hours_present = n(),
            valid_hours = sum(is.finite(temperature_c)),
            mean_c = mean(temperature_c), .groups = "drop")

# Include every expected date so entirely missing nights are also detected.
calendar <- data.frame(night_date = seq(as.Date("2000-01-01"),
                                       as.Date("2025-12-31"), by = "day"))
nightly <- left_join(calendar, nightly, by = "night_date")
nightly$hours_present <- coalesce(nightly$hours_present, 0L)
nightly$valid_hours <- coalesce(nightly$valid_hours, 0L)
nightly$complete <- nightly$hours_present == 10 & nightly$valid_hours == 10
nightly$mean_c[!nightly$complete] <- NA
nightly$year <- as.integer(format(nightly$night_date, "%Y"))
nightly$month <- as.integer(format(nightly$night_date, "%m"))

quality_checks <- data.frame(
  hourly_rows = nrow(weather),
  missing_temperatures = sum(is.na(weather$temperature_c)),
  complete_nights = sum(nightly$complete),
  incomplete_nights = sum(!nightly$complete)
)
print(quality_checks)
print(head(nightly))
write.csv(quality_checks, file.path(output_folder, "quality_checks.csv"), row.names = FALSE)
write.csv(nightly, file.path(output_folder, "nightly.csv"), row.names = FALSE)

# HANDOFF: Member 2 uses the nightly table created here.


# ========================================================================
# PART 2 - MEMBER 2: SUMMARIZE AND DESCRIBE THE TEMPERATURES
# Question: What do nighttime temperatures generally look like?
# Run Part 1 first, in the same R session.
# ========================================================================

stopifnot(any(nightly$complete))
descriptive <- data.frame(
  city = city,
  mean_c = mean(nightly$mean_c, na.rm = TRUE),
  median_c = median(nightly$mean_c, na.rm = TRUE),
  sd_c = sd(nightly$mean_c, na.rm = TRUE),
  minimum_c = min(nightly$mean_c, na.rm = TRUE),
  maximum_c = max(nightly$mean_c, na.rm = TRUE)
)

monthly <- nightly |>
  group_by(year, month) |>
  summarise(expected_nights = n(), valid_nights = sum(complete),
            coverage = valid_nights / expected_nights,
            mean_c = mean(mean_c, na.rm = TRUE), .groups = "drop") |>
  arrange(year, month)

annual <- nightly |>
  group_by(year) |>
  summarise(expected_nights = n(), valid_nights = sum(complete),
            coverage = valid_nights / expected_nights,
            mean_c = mean(mean_c, na.rm = TRUE), .groups = "drop")

# Require at least 90% complete nights in EVERY month and year.
# Stop for investigation instead of silently ignoring poor coverage.
stopifnot(nrow(monthly) == 312, all(monthly$coverage >= .90))
stopifnot(all(is.finite(monthly$mean_c)))
stopifnot(nrow(annual) == 26, all(annual$coverage >= .90))

seasonal <- monthly |>
  group_by(month) |>
  summarise(mean_c = mean(mean_c), .groups = "drop")

print(descriptive)
print(annual, n = 26)
write.csv(descriptive, file.path(output_folder, "descriptive.csv"), row.names = FALSE)
write.csv(monthly, file.path(output_folder, "monthly.csv"), row.names = FALSE)
write.csv(annual, file.path(output_folder, "annual.csv"), row.names = FALSE)

# Graph 1: Yearly averages. The same scales are used for every city.
png(file.path(graph_folder, "01_annual_mean_temperature.png"),
    width = 2000, height = 1200, res = 200)
par(mar = c(5, 5, 4, 2), las = 1)
plot(annual$year, annual$mean_c, type = "o", pch = 19, col = "firebrick",
     xlim = c(2000, 2025), ylim = c(22, 32),
     xlab = "Year", ylab = "Nighttime temperature (°C)",
     main = paste(city, "- Annual Mean Nighttime Temperature"),
     sub = "Graph type: Line graph (time series)")
dev.off()

# Graph 2: The spread of nightly averages within each year.
png(file.path(graph_folder, "02_yearly_boxplots.png"),
    width = 2000, height = 1200, res = 200)
par(mar = c(5, 5, 4, 2), las = 1)
boxplot(mean_c ~ year, data = nightly, col = "lightblue", outline = FALSE,
        ylim = c(18, 34), xlab = "Year", ylab = "Nightly mean temperature (°C)",
        main = paste(city, "- Distribution of Nightly Averages"),
        sub = "Graph type: Box-and-whisker plot")
mtext("Boxes show the middle 50%; extreme points are hidden for readability.", side = 3, cex = .8)
dev.off()

# Graph 3: The average seasonal pattern across all 26 years.
png(file.path(graph_folder, "03_seasonal_pattern.png"),
    width = 2000, height = 1200, res = 200)
par(mar = c(5, 5, 4, 2), las = 1)
plot(seasonal$month, seasonal$mean_c, type = "o", pch = 19, col = "firebrick",
     xaxt = "n", ylim = c(22, 32), xlab = "Month", ylab = "Temperature (°C)",
     main = paste(city, "- Seasonal Pattern, 2000-2025"),
     sub = "Graph type: Line graph (seasonal profile)")
axis(1, at = 1:12, labels = month.abb)
dev.off()

# HANDOFF: Member 3 uses monthly; Member 4 uses nightly.


# ========================================================================
# PART 3 - MEMBER 3: REGRESSION AND TEMPERATURE TREND TESTING
# Question: Are nighttime temperatures increasing over time?
# Run Parts 1 and 2 first, in the same R session.
# ========================================================================

# Express time in decades so the slope is directly in degrees C per decade.
monthly$time_decades <- ((monthly$year - 2000) * 12 + monthly$month - 1) / 120

# factor(month) accounts for the regular seasonal cycle.
temperature_model <- lm(mean_c ~ time_decades + factor(month), data = monthly)

# Consecutive months may be related. Newey-West adjusts the uncertainty.
# Twelve lags means allowing dependence across up to 12 monthly steps.
adjusted_errors <- NeweyWest(temperature_model, lag = 12,
                             prewhite = FALSE, adjust = TRUE)
slope <- unname(coef(temperature_model)["time_decades"])
standard_error <- sqrt(adjusted_errors["time_decades", "time_decades"])

temperature_trend <- data.frame(
  city = city,
  change_c_per_decade = slope,
  standard_error = standard_error,
  ci_low = slope - 1.96 * standard_error,
  ci_high = slope + 1.96 * standard_error,
  p_value = 2 * pnorm(-abs(slope / standard_error))
)
print(temperature_trend)
# Positive slope: warming. Negative slope: cooling.
# The two-sided p-value tests whether the slope differs from zero.
# The confidence interval shows uncertainty; it is not the range of temperatures.
write.csv(temperature_trend, file.path(output_folder, "temperature_trend.csv"), row.names = FALSE)

# An anomaly is a monthly temperature minus its baseline calendar-month mean.
baseline_means <- monthly |>
  filter(year <= 2009) |>
  group_by(month) |>
  summarise(baseline_c = mean(mean_c), .groups = "drop")
monthly <- left_join(monthly, baseline_means, by = "month")
monthly$anomaly_c <- monthly$mean_c - monthly$baseline_c
monthly$date <- as.Date(sprintf("%04d-%02d-01", monthly$year, monthly$month))
write.csv(monthly, file.path(output_folder, "monthly.csv"), row.names = FALSE)

# Graph 4: Months above or below their 2000-2009 calendar-month average.
png(file.path(graph_folder, "04_monthly_anomalies.png"),
    width = 2000, height = 1200, res = 200)
par(mar = c(5, 5, 4, 2), las = 1)
plot(monthly$date, monthly$anomaly_c, type = "l", col = "firebrick",
     ylim = c(-5, 5), xlab = "Year", ylab = "Temperature anomaly (°C)",
     main = paste(city, "- Monthly Anomalies from the 2000-2009 Baseline"),
     sub = "Graph type: Line graph (time series)")
abline(h = 0, lty = 2, col = "steelblue")
dev.off()

# Graph 7: Check how strongly model errors are related across months.
png(file.path(graph_folder, "07_residual_autocorrelation.png"),
    width = 2000, height = 1200, res = 200)
par(mar = c(5, 5, 4, 2), las = 1)
acf(residuals(temperature_model), lag.max = 36,
    main = paste(city, "- Monthly Regression Residual Autocorrelation"),
    xlab = "Lag (months)",
    sub = "Graph type: Autocorrelation plot (correlogram)")
dev.off()

# HANDOFF: Share the trend estimate, confidence interval, and p-value with the group.


# ========================================================================
# PART 4 - MEMBER 4: FREQUENCY OF UNUSUALLY WARM NIGHTS
# Question: Are unusually warm nights becoming more frequent?
# Run Parts 1 and 2 first, in the same R session.
# ========================================================================

# Our fixed baseline is 2000-2009, using complete nights only.
# A separate 90th percentile for each month accounts for seasonal differences.
# This is a study-specific definition, not an official heat-warning index.
thresholds <- nightly |>
  filter(year >= 2000, year <= 2009, complete) |>
  group_by(month) |>
  summarise(threshold_c = as.numeric(quantile(mean_c, .90, type = 7)),
            baseline_nights = n(), .groups = "drop")

nightly <- left_join(nightly, thresholds, by = "month")
nightly$unusually_warm <- nightly$mean_c > nightly$threshold_c

warm_annual <- nightly |>
  group_by(year) |>
  summarise(valid_nights = sum(complete),
            warm_nights = sum(unusually_warm, na.rm = TRUE),
            warm_percent = 100 * warm_nights / valid_nights, .groups = "drop")
warm_annual$time_decades <- (warm_annual$year - 2000) / 10

print(thresholds)
print(warm_annual, n = 26)

# Test whether the annual warm-night percentage changes over time.
warm_model <- lm(warm_percent ~ time_decades, data = warm_annual)
warm_errors <- NeweyWest(warm_model, lag = 3, prewhite = FALSE, adjust = TRUE)
warm_slope <- unname(coef(warm_model)["time_decades"])
warm_se <- sqrt(warm_errors["time_decades", "time_decades"])

warm_trend <- data.frame(
  city = city,
  percentage_points_per_decade = warm_slope,
  standard_error = warm_se,
  ci_low = warm_slope - 1.96 * warm_se,
  ci_high = warm_slope + 1.96 * warm_se,
  p_value = 2 * pnorm(-abs(warm_slope / warm_se))
)
print(warm_trend)
# The slope is in PERCENTAGE POINTS per decade, not degrees C.
# This describes the study period; it is not a forecast.

write.csv(nightly, file.path(output_folder, "nightly.csv"), row.names = FALSE)
write.csv(thresholds, file.path(output_folder, "thresholds.csv"), row.names = FALSE)
write.csv(warm_annual, file.path(output_folder, "warm_annual.csv"), row.names = FALSE)
write.csv(warm_trend, file.path(output_folder, "warm_trend.csv"), row.names = FALSE)

# Graph 5: Percentage is more comparable when valid-night counts differ.
png(file.path(graph_folder, "05_warm_night_percentage.png"),
    width = 2000, height = 1200, res = 200)
par(mar = c(5, 5, 4, 2), las = 1)
plot(warm_annual$year, warm_annual$warm_percent, type = "o", pch = 19,
     col = "firebrick", xlim = c(2000, 2025), ylim = c(0, 100),
     xlab = "Year", ylab = "Valid nights above threshold (%)",
     main = paste(city, "- Percentage of Unusually Warm Nights"),
     sub = "Graph type: Line graph (time series)")
dev.off()

# Graph 6: Actual counts, without estimating values for missing nights.
png(file.path(graph_folder, "06_warm_night_count.png"),
    width = 2000, height = 1200, res = 200)
par(mar = c(5, 5, 4, 2), las = 1)
plot(warm_annual$year, warm_annual$warm_nights, type = "o", pch = 19,
     col = "firebrick", xlim = c(2000, 2025), ylim = c(0, 366),
     xlab = "Year", ylab = "Observed warm nights",
     main = paste(city, "- Number of Unusually Warm Nights"),
     sub = "Graph type: Line graph (time series)")
dev.off()

capture.output(sessionInfo(), file = file.path(output_folder, "sessionInfo.txt"))
message("Finished. Tables and seven labeled PNG graphs: ", normalizePath(output_folder))

# GROUP TASK: Combine the separately analyzed cities' results later.
# Written report: explain the problem, dataset, 2-3 related papers, screenshots,
# and conclusions. These are not automatically written by the script.
