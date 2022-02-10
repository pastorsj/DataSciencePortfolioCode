# ------------------Libraries------------------
if (!require("pacman")) {
  install.packages("pacman")
}

pacman::p_load(tidyverse, gridExtra, TSstudio, 
               fpp, forecast, astsa, lubridate, zoo) 
# ---------------------------------------------

weather.df <- read.csv('../cleaned_data/weather/weather_data.csv') %>% drop_na()
head(weather.df)

# Start with California
temperature.ts.ca <- weather.df %>%
  filter(StateAbbreviation == 'CA') %>%
  select(AverageTemperature) %>%
  ts(start = c(1895, 1), end = c(2021, 12), frequency = 12)

png('../eda_visualizations/weather/basic_time_series_temperature.png', width = 8, height = 6, units = 'in', res = 400)
plot(temperature.ts.ca, xlab = "Year (1895-2021)", ylab = 'Average Temperature', main = 'Average Temperature in California')
dev.off()

# Plot the data
viz <- autoplot(temperature.ts.ca) +
  ggtitle("Average Temperature in California") +
  xlab("Year (1895-2021)") +
  ylab("Average Temperature")

ggsave('../eda_visualizations/weather/temperature_time_series.svg', width = 10, height = 6, units = 'in')
print(viz)
dev.off()

html.viz <- ts_plot(temperature.ts.ca, 
                    Xtitle = "Year (1895-2021)", 
                    Ytitle = 'Average Temperature', 
                    title = 'Average Temperature in California')
htmlwidgets::saveWidget(html.viz, "../eda_visualizations/weather/temperature_time_series.html")


# Lag Plots
viz <- gglagplot(temperature.ts.ca, do.lines = FALSE) +
  ggtitle("Lag Plots of Average Temperature in California")

ggsave('../eda_visualizations/weather/temperature_lag_plots.svg', width = 8, height = 8, units = 'in')
print(viz)
dev.off()


# Interactive Lag Plots
html.viz <- ts_lags(temperature.ts.ca)
htmlwidgets::saveWidget(html.viz, "../eda_visualizations/weather/temperature_lag_plots.html")

# Interactive Seasonality Plots
html.viz <- ts_seasonal(temperature.ts.ca, type = 'all', title = 'Seasonality Plot of Average Temperature in California')
htmlwidgets::saveWidget(html.viz, "../eda_visualizations/weather/temperature_seasonality.html")

temperature.window.ts <- window(temperature.ts.ca, start = c(2000, 1), end = c(2020, 12))
html.viz <- ts_heatmap(temperature.window.ts, title = 'Heatmap of Average Temperature in California (2010-2020)')
htmlwidgets::saveWidget(html.viz, "../eda_visualizations/weather/temperature_seasonality_heatmap.html")

# Take a look at the trend
temperature.trend <- ma(temperature.ts.ca, order = 12, centre = T)
png('../eda_visualizations/weather/trended_time_series_temperature.png')
plot(temperature.ts.ca, xlab = "Year (1895-2021)", ylab = 'Average Temperature', main = 'Average Temperature in California')
lines(temperature.trend)
dev.off()

# Try additive
temperature.decomp <- decompose(temperature.ts.ca, "additive")
viz <- autoplot(temperature.decomp) +
  ggtitle("Decomposition of Average Temperature in California Time Series") +
  xlab("Year (1895-2021)")

ggsave('../eda_visualizations/weather/decomposition_temperature.svg', width = 10, height = 6, units = 'in')
print(viz)
dev.off()

# Try STL approach
temperature.stl <- stl(temperature.ts.ca[, 1], s.window = 'periodic')
autoplot(temperature.stl) # Almost exactly the same output as above

# Take a look at the ACF and PACF graphs
png('../eda_visualizations/weather/basic_temperature_acf_plot.png', width = 8, height = 6, units = 'in', res = 400)
acf(temperature.ts.ca, main = 'ACF of Average Temperature in California Time Series')
dev.off()

png('../eda_visualizations/weather/basic_temperature_pacf_plot.png', width = 8, height = 6, units = 'in', res = 400)
pacf(temperature.ts.ca, main = 'PACF of Average Temperature in California Time Series')
dev.off()

acf.1 <- ggAcf(temperature.ts.ca) +
  ggtitle("ACF of Average Temperature in California Time Series")
acf.2 <- ggAcf(temperature.ts.ca - temperature.decomp$seasonal) +
  ggtitle("ACF of Average Temperature in California Time Series (Remove Seasonal)")
acf.3 <- ggAcf(diff(temperature.ts.ca - temperature.decomp$seasonal)) +
  ggtitle("ACF of Average Temperature in California Time Series (1-Diff, Remove Seasonal)")

png('../eda_visualizations/weather/combined_temperature_acf_plots.png', width = 8, height = 8, units = 'in', res = 400)
grid.arrange(acf.1, acf.2, acf.3, ncol = 1)
dev.off()

# Confirm stationarity using Augmented Dickey Fuller Test
tseries::adf.test(temperature.ts.ca)

# Final plot of ACF after diff
ggsave('../eda_visualizations/weather/temperature_stationary_acf_plot.svg', width = 8, height = 6, units = 'in')
ggAcf(diff(temperature.ts.ca - temperature.decomp$seasonal))
dev.off()

readr::write_csv(as.data.frame(tsibble::as_tsibble(temperature.ts.ca)), '../cleaned_data/weather/temperature_time_series.csv')
