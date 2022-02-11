# ------------------Libraries------------------
if (!require("pacman")) {
  install.packages("pacman")
}

pacman::p_load(tidyverse, gridExtra, TSstudio, 
               fpp, forecast, astsa, lubridate, zoo) 
# ---------------------------------------------

flood.df <- read.csv('../cleaned_data/floods/aggregated_flood_data.csv') %>% drop_na()
head(flood.df)

# Start with California
flood.ts.ca <- flood.df %>%
  filter(StateAbbreviation == 'CA') %>%
  select(NumberOfFloods) %>%
  ts(start = c(2006, 1), end = c(2020, 12), frequency = 12)

png('../eda_visualizations/floods/basic_time_series_floods.png', width = 8, height = 6, units = 'in', res = 400)
plot(flood.ts.ca, xlab = "Year (2006-2020)", ylab = 'Number of Floods', main = 'California Floods')
dev.off()

# Plot the data
viz <- autoplot(flood.ts.ca) +
  ggtitle("California Floods") +
  xlab("Year (2006-2020)") +
  ylab("Number of Floods")

ggsave('../eda_visualizations/floods/flood_time_series.svg', width = 10, height = 6, units = 'in')
print(viz)
dev.off()

html.viz <- ts_plot(flood.ts.ca, 
                    Xtitle = "Year (2006-2020)", 
                    Ytitle = 'Number of Floods', 
                    title = 'California Floods')
htmlwidgets::saveWidget(html.viz, "../eda_visualizations/floods/flood_time_series.html")


# Lag Plots
viz <- gglagplot(flood.ts.ca, do.lines = FALSE) +
  ggtitle("Lag Plots of California Floods")

ggsave('../eda_visualizations/floods/flood_lag_plots.svg', width = 8, height = 8, units = 'in')
print(viz)
dev.off()


# Interactive Lag Plots
html.viz <- ts_lags(flood.ts.ca)
htmlwidgets::saveWidget(html.viz, "../eda_visualizations/floods/flood_lag_plots.html")

# Interactive Seasonality Plots
html.viz <- ts_seasonal(flood.ts.ca, type = 'all', title = 'Seasonality Plot of California Floods')
htmlwidgets::saveWidget(html.viz, "../eda_visualizations/floods/flood_seasonality.html")

html.viz <- ts_heatmap(flood.ts.ca, title = 'Seasonality Heatmap of California Floods')
htmlwidgets::saveWidget(html.viz, "../eda_visualizations/floods/flood_seasonality_heatmap.html")

# Take a look at the trend
flood.trend <- ma(flood.ts.ca, order = 12, centre = T)
png('../eda_visualizations/floods/trended_time_series_floods.png')
plot(flood.ts.ca, xlab = "Year (2006-2020)", ylab = 'Number of Floods', main = 'California Floods')
lines(flood.trend)
dev.off()

# Try multiplicative
flood.decomp <- decompose(flood.ts.ca, "multiplicative")
viz <- autoplot(flood.decomp) +
  ggtitle("Decomposition of California Floods Time Series") +
  xlab("Year (2006-2020)")

ggsave('../eda_visualizations/floods/decomposition_floods.svg', width = 10, height = 6, units = 'in')
print(viz)
dev.off()

# Try STL approach
flood.stl <- stl(flood.ts.ca, s.window = 'periodic')
autoplot(flood.stl) # Almost exactly the same output as above

# Take a look at the ACF and PACF graphs
png('../eda_visualizations/floods/basic_flood_acf_plot.png', width = 8, height = 6, units = 'in', res = 400)
acf(flood.ts.ca, main = 'ACF of California Floods Time Series')
dev.off()

png('../eda_visualizations/floods/basic_flood_pacf_plot.png', width = 8, height = 6, units = 'in', res = 400)
pacf(flood.ts.ca, main = 'PACF of California Floods Time Series')
dev.off()

# Confirm stationarity using Augmented Dickey Fuller Test
tseries::adf.test(flood.ts.ca)

# Final plot of ACF after diff
ggsave('../eda_visualizations/floods/flood_stationary_acf_plot.svg', width = 8, height = 6, units = 'in')
ggAcf(flood.ts.ca, lag.max = 20) +
  ggtitle("ACF Plot of California Floods")
dev.off()

readr::write_csv(as.data.frame(tsibble::as_tsibble(flood.ts.ca)), '../cleaned_data/floods/flood_time_series.csv')