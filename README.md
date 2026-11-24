# Walang Pahingang Init

**A statistical study of nighttime temperature in Manila, 2000–2025.**

This RStudio course project investigates two questions:

1. Are nighttime temperatures increasing over time?
2. Are unusually warm nights becoming more frequent?

The repository contains one readable R script, divided into **four parts for four group members**. It analyzes **one city per run**. Manila is configured first; the same script can later be reused for Cebu City and Davao City by changing the city name and CSV path.

## What is included

| File | Purpose |
| --- | --- |
| [`manila_simple.R`](manila_simple.R) | Complete four-part analysis, including data checks, statistical calculations, tables, and seven labeled PNG graphs |
| `README.md` | Setup, data requirements, member responsibilities, explanations, and report guidance |

**The dataset and generated results are not included.** Download your own CSV and run the script locally. The script reads local data and does not call an API, download data, or publish results.

## Quick start

### 1. Get the project

```sh
git clone https://github.com/adr1el-m/ds.git
cd ds
```

Open `manila_simple.R` in RStudio. Set the working directory to the downloaded `ds` folder so outputs are saved inside the project. You can check it using `getwd()`.

Use **R 4.1 or newer** because the script uses the native `|>` pipe. The pipe passes the result of one step into the next step.

### 2. Install the packages once

Run this in the RStudio console:

```r
install.packages(c("dplyr", "sandwich"))
```

`dplyr` groups and summarizes the data. `sandwich` provides the Newey–West uncertainty estimates used in the trend tests. The graphs use base R.

### 3. Set the city and CSV path

At the beginning of Part 1, edit:

```r
city <- "Manila"
csv_path <- "~/Downloads/manila-2000-2025.csv"
```

Use your own file location. On Windows, a path can look like `"C:/Users/YourName/Downloads/manila-2000-2025.csv"`; forward slashes work in R strings.

### 4. Run the script

Click **Source** in RStudio, or run this from the repository folder:

```r
source("manila_simple.R")
```

You can also use a terminal:

```sh
Rscript manila_simple.R
```

To study it section by section, run **Part 1 → Part 2 → Part 3 → Part 4 in the same R session**. Later sections use tables created earlier. Parts 3 and 4 both require Parts 1 and 2; Part 4 does not need Part 3's model.

## Prepare the dataset

Use the [Open-Meteo Historical Weather API](https://open-meteo.com/en/docs/historical-weather-api) and export a CSV with these settings:

| Setting | Value |
| --- | --- |
| Manila reference latitude | `14.604` |
| Manila reference longitude | `120.982` |
| Start date | `2000-01-01` |
| End date | `2026-01-01` |
| Timezone | Automatically detect time zone; the export must use UTC+8 |
| Hourly variable | Temperature (2 m) only |
| Reanalysis model | ERA5 only |
| Temperature unit | Celsius |

The extra day completes the night beginning **December 31, 2025**. The study uses readings only through **January 1, 2026 at 5:00 AM** for that final night.

ERA5 is a reanalysis dataset: it combines observations with weather modeling to estimate historical conditions. It represents a grid location rather than every neighborhood. Open-Meteo recommends ERA5 or ERA5-Land for multi-decade analysis; this project selects **ERA5 consistently for every city**. See the [data-source documentation](https://open-meteo.com/en/docs/historical-weather-api#data-sources).

Keep the original CSV structure: metadata header, metadata values, a blank line, then the hourly header and observations. The script uses `skip = 3` to reach the hourly table. Do not remove those metadata rows or export additional variables. Standard CSV metadata does not identify the selected weather model, so verify **ERA5** in the export settings yourself.

## How one night is defined

A research night contains **10 hourly temperature readings**, including both endpoints:

| Night label | Included readings |
| --- | --- |
| January 1, 2000 | January 1, 8 PM–11 PM; January 2, midnight–5 AM |

The date label always refers to the evening on which the night began. The intended study includes **9,497 nights**, beginning January 1, 2000 through December 31, 2025.

Only a night with all 10 valid readings receives a mean temperature. Incomplete nights remain in the table with `NA` means; missing temperatures are not filled in. A complete date calendar makes entirely missing nights visible too.

## Four members, four parts

### Member 1 — Prepare and validate the data

**Question:** Do we have usable nighttime data?

- Import the CSV and check its timezone, columns, and Celsius unit.
- Convert timestamps and temperatures into their proper R types.
- Reject invalid or repeated timestamps, off-hour readings, and invalid numeric values.
- Select nighttime hours and group them by the evening's date.
- Identify complete and incomplete nights.

**Learn:** `read.csv()`, `as.POSIXct()`, `filter()`, `group_by()`, `summarise()`, and `left_join()`.

**Explain to the group:** Why early-morning readings belong to the previous evening, why completeness matters, and how the script handles missing data.

**Screenshot:** `quality_checks` and `head(nightly)`.

### Member 2 — Describe the temperatures

**Question:** What are the typical values, spread, and seasonal patterns?

- Calculate the overall mean, median, standard deviation, minimum, and maximum of nightly means.
- Calculate monthly and annual averages and check coverage.
- Require at least **90% complete nights in every month and every year** before continuing.
- Produce annual line graphs, yearly boxplots, and a seasonal-profile graph.

**Learn:** `mean()`, `median()`, `sd()`, `min()`, `max()`, `plot()`, and `boxplot()`.

**Explain to the group:** The difference between an hourly reading, a nightly mean, and a monthly/yearly average. Overall minimum and maximum refer to **nightly averages**, not the single coldest or hottest hourly reading.

**Screenshot:** `descriptive`, `annual`, and graphs 1–3.

### Member 3 — Test the temperature trend

**Question:** Are nights getting warmer, and by how much?

The monthly regression is:

```r
mean_c ~ time_decades + factor(month)
```

`time_decades` measures time in ten-year units. `factor(month)` allows each calendar month its own seasonal effect. The time coefficient estimates temperature change in **°C per decade**.

The script uses Newey–West standard errors with **12 monthly lags**, plus a two-sided asymptotic normal test and approximate 95% confidence interval. This regression slope test is the temperature trend test; there is no separate Mann–Kendall test.

**Learn:** `lm()`, `coef()`, `factor()`, `NeweyWest()`, confidence intervals, and p-values.

**Explain to the group:** A positive slope indicates estimated warming; a negative slope indicates cooling. The interval describes uncertainty in that slope. Newey–West adjusts uncertainty for dependence and unequal error variance; it does not remove autocorrelation or change the fitted slope. See the [`sandwich` manual](https://stat.ethz.ch/CRAN/web/packages/sandwich/sandwich.pdf).

This section also calculates monthly anomalies relative to the **2000–2009 average for the same calendar month**, then plots anomalies and residual autocorrelation.

**Screenshot:** `temperature_trend` and graphs 4 and 7. Explain the estimated change, its interval, and its p-value together.

### Member 4 — Analyze unusually warm nights

**Question:** Are unusually warm nights becoming more frequent?

- Use **2000–2009** as a fixed baseline.
- Calculate a separate **90th percentile** of nightly mean temperature for each calendar month.
- Classify a night as unusually warm when its mean is **strictly above** that month's threshold.
- Calculate annual observed counts and percentages using complete nights as the denominator.
- Regress annual percentages on time in decades, using Newey–West uncertainty with **3 annual lags**.

**Learn:** `quantile()`, `>`, counting logical values with `sum()`, percentages, and the regression approach from Part 3.

**Explain to the group:** The frequency slope is in **percentage points per decade**, not °C per decade. A change from 10% to 20% is an increase of 10 percentage points. Counts are observed counts, not estimates for missing nights.

The warm-night rule is a **study-specific definition** based on nightly mean temperature, not an official heat-warning index. The ten-year baseline, percentile, and coverage rule are study choices that should be documented and reviewed with the instructor.

**Screenshot:** `thresholds`, `warm_annual`, `warm_trend`, and graphs 5–6.

## Generated files

For Manila, results are saved relative to your working directory:

```text
outputs/simple_manila/
├── quality_checks.csv
├── nightly.csv
├── descriptive.csv
├── monthly.csv
├── annual.csv
├── temperature_trend.csv
├── thresholds.csv
├── warm_annual.csv
├── warm_trend.csv
├── sessionInfo.txt
└── graphs_png/
    ├── 01_annual_mean_temperature.png
    ├── 02_yearly_boxplots.png
    ├── 03_seasonal_pattern.png
    ├── 04_monthly_anomalies.png
    ├── 05_warm_night_percentage.png
    ├── 06_warm_night_count.png
    └── 07_residual_autocorrelation.png
```

Graphs are **2000 × 1200 PNGs at 200 dpi**, with graph-type labels. Each city uses the same graph sizes, colors, and fixed scales. The boxplots hide extreme points for readability; their values remain in the tables. If another city's values fall outside the fixed axes, adjust the relevant axes consistently for **all** cities before comparing them.

The script writes PNGs directly. It does not generate a PDF. Rerunning replaces that city's generated files. CSVs retain numerical precision; round values when preparing the report. `sessionInfo.txt` records the R and package versions used.

## Reuse for Cebu City or Davao City

Change only the city name and input path at the top of Part 1, for example:

```r
city <- "Cebu City"
csv_path <- "~/Downloads/cebu-2000-2025.csv"
```

Then rerun the entire script. This creates a separate output folder, such as `outputs/simple_cebu_city/`. Repeat for Davao City.

Keep the dates, model, nighttime definition, baseline, percentile rule, coverage requirement, and statistical methods consistent. Warm-night thresholds differ in degrees between cities because each city's seasonal baseline is calculated separately.

Afterward, compare their tables and graphs as a group. The script **does not combine the three cities or perform formal between-city significance tests**. Different slopes or different individual p-values alone do not establish a statistically significant difference between two cities.

## Useful commands for studying and screenshots

After running the script:

```r
print(quality_checks)
head(nightly)
print(descriptive)
print(annual, n = 26)
print(temperature_trend)
print(thresholds)
print(warm_annual, n = 26)
print(warm_trend)
```

Select a command and run it to obtain a focused console screenshot. Graphs are saved directly to `graphs_png/`; open those files to view them. They may not appear in RStudio's Plots pane because the script opens PNG devices.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Cannot open the CSV | Check `csv_path`, the filename, and the file's actual location. |
| Package not found | Run the package installation command before sourcing the script. |
| Object such as `nightly` or `monthly` not found | Run the preceding parts in the same R session. |
| UTC offset check fails | Re-export using the location's local timezone, UTC+8. Changing `tz` in R does not convert an incorrectly exported UTC file. |
| Column or Celsius check fails | Retain metadata and export only hourly Temperature (2 m), Celsius, with one model. |
| Timestamp or numeric-value check fails | Inspect the original file; investigate invalid, duplicate, malformed, or off-hour observations. |
| Coverage check fails | Review incomplete nights and download coverage. Do not remove the check to force a result. |
| Fewer than 10 readings on December 31, 2025 | Include January 1, 2026 in the download. |
| Graphs seem missing | Run `getwd()` and look under that directory's `outputs/` folder. |

## What remains for the written report

The script supplies the calculations and visualizations. The course report still needs:

1. A description of the problem area and why it matters.
2. The dataset, source, selected coordinates, coverage, and collection procedure.
3. **Two or three related papers**, with a reason for selecting each.
4. The experiment's purpose and research questions.
5. Screenshots of R calculations, each accompanied by an explanation.
6. Conclusions supported by the actual results, their importance, and limitations.

The documentation links here explain tools and data sources; they do not constitute the group's required literature review. Reanalysis grid estimates and time trends do not establish causes such as urbanization, nor do they capture every neighborhood's exposure. Treat the fitted trends as summaries of 2000–2025, not forecasts or guarantees about future conditions.

## Validation

The current four-part script has been run successfully on the local Manila CSV: **9,497 complete nights** were processed and all seven PNG graphs were generated and visually checked. The temperature and warm-frequency trend estimates match the earlier version of the analysis.

Those checks establish that this script runs on the tested Manila export. Cebu City and Davao City require their own correctly configured files and coverage checks before their results can be reported.
