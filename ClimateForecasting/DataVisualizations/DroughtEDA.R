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
drought.ts.ca <- weather.df %>%
  filter(StateAbbreviation == 'CA') %>%
  select(DroughtIndex) %>%
  ts(start = c(1895, 1), end = c(2021, 12), frequency = 12)

png('../eda_visualizations/drought/basic_time_series_droughts.png', width = 8, height = 6, units = 'in', res = 400)
plot(drought.ts.ca, xlab = "Year (1895-2021)", ylab = 'Drought Index', main = 'California Droughts')
dev.off()

# Plot the data
viz <- autoplot(drought.ts.ca) +
  ggtitle("California Droughts") +
  xlab("Year (1895-2021)") +
  ylab("Drought Index")

ggsave('../eda_visualizations/drought/droughts_time_series.svg', width = 10, height = 6, units = 'in')
print(viz)
dev.off()

html.viz <- ts_plot(drought.ts.ca, 
                    Xtitle = "Year (1895-2021)", 
                    Ytitle = 'Drought Index', 
                    title = 'California Droughts')
htmlwidgets::saveWidget(html.viz, "../eda_visualizations/drought/drought_time_series.html")


# Lag Plots
viz <- gglagplot(drought.ts.ca, do.lines = FALSE) +
  ggtitle("Lag Plots of California Droughts")

ggsave('../eda_visualizations/drought/drought_lag_plots.svg', width = 8, height = 8, units = 'in')
print(viz)
dev.off()

png('../eda_visualizations/drought/drought_lag_plots.png', width = 8, height = 8, units = 'in', res = 400)
print(viz)
dev.off()


# Interactive Lag Plots
html.viz <- ts_lags(drought.ts.ca)
htmlwidgets::saveWidget(html.viz, "../eda_visualizations/drought/drought_lag_plots.html")

# Interactive Seasonality Plots
html.viz <- ts_seasonal(drought.ts.ca, type = 'all', title = 'Seasonality Plot of California Droughts')
htmlwidgets::saveWidget(html.viz, "../eda_visualizations/drought/drought_seasonality.html")

drought.window.ts <- window(drought.ts.ca, start = c(2000, 1), end = c(2020, 12))
html.viz <- ts_heatmap(drought.window.ts, title = 'Heatmap of California Droughts (2000-2020)')
htmlwidgets::saveWidget(html.viz, "../eda_visualizations/drought/drought_seasonality_heatmap.html")

# Take a look at the trend
drought.trend <- ma(drought.ts.ca, order = 12, centre = T)
png('../eda_visualizations/drought/trended_time_series_droughts.png')
plot(drought.ts.ca, xlab = "Year (1895-2021)", ylab = 'Drought Index', main = 'California Droughts')
lines(drought.trend)
dev.off()

# Try multiplicative
drought.decomp <- decompose(drought.ts.ca, "multiplicative")
viz <- autoplot(drought.decomp) +
  ggtitle("Decomposition of California Droughts Time Series") +
  xlab("Year (1895-2021)")

ggsave('../eda_visualizations/drought/decomposition_droughts.svg', width = 10, height = 6, units = 'in')
print(viz)
dev.off()

# Try STL approach
drought.stl <- stl(drought.ts.ca, s.window = 'periodic')
autoplot(drought.stl) # Almost exactly the same output as above

# Take a look at the ACF and PACF graphs
png('../eda_visualizations/drought/basic_drought_acf_plot.png', width = 8, height = 6, units = 'in', res = 400)
acf(drought.ts.ca, main = 'ACF of California Droughts Time Series')
dev.off()

png('../eda_visualizations/drought/basic_drought_pacf_plot.png', width = 8, height = 6, units = 'in', res = 400)
pacf(drought.ts.ca, main = 'PACF of California Droughts Time Series')
dev.off()

# Confirm stationarity using Augmented Dickey Fuller Test
tseries::adf.test(drought.ts.ca)

acf.1 <- ggAcf(drought.ts.ca) +
  ggtitle("ACF of California Droughts Time Series")
acf.2 <- ggAcf(diff(drought.ts.ca)) +
  ggtitle("ACF of California Droughts Time Series (1-Diff)")
acf.3 <- ggAcf(diff(diff(drought.ts.ca))) +
  ggtitle("ACF of California Droughts Time Series (2-Diff)")

png('../eda_visualizations/drought/combined_drought_acf_plots.png', width = 8, height = 8, units = 'in', res = 400)
grid.arrange(acf.1, acf.2, acf.3, ncol = 1)
dev.off()

# Final plot of ACF after differencing to remove correlation
ggsave('../eda_visualizations/drought/drought_stationary_acf_plot.svg', width = 8, height = 6, units = 'in')
ggAcf(diff(diff(drought.ts.ca))) +
  ggtitle("ACF of California Droughts Time Series")
dev.off()

# Moving Average Smoothing
viz.2 <- autoplot(drought.ts.ca, series = 'Data') +
  autolayer(ma(drought.ts.ca, 5), series = '4 month MA') +
  ggtitle("California Droughts (4 Year Moving Average)") +
  xlab("Year (1895-2021)") +
  ylab("Drought Index") +
  scale_colour_manual(values=c("Data" = "grey50","4 month MA"="red"),
                      breaks=c("Data","4 month MA"))
ggsave('../eda_visualizations/drought/drought_moving_average_4_month.svg', plot = viz.2, width = 10, height = 6, units = 'in')

viz.1 <- autoplot(drought.ts.ca, series = 'Data') +
  autolayer(ma(drought.ts.ca, 13), series = '1 year MA') +
  ggtitle("California Droughts (1 Year Moving Average)") +
  xlab("Year (1895-2021)") +
  ylab("Drought Index") +
  scale_colour_manual(values=c("Data" = "grey50","1 year MA"="red"),
                      breaks=c("Data","1 year MA"))
ggsave('../eda_visualizations/drought/drought_moving_average_1_year.svg', plot = viz.1, width = 10, height = 6, units = 'in')

viz.5 <- autoplot(drought.ts.ca, series = 'Data') +
  autolayer(ma(drought.ts.ca, 61), series = '5 year MA') +
  ggtitle("California Droughts (5 Year Moving Average)") +
  xlab("Year (1895-2021)") +
  ylab("Drought Index") +
  scale_colour_manual(values=c("Data" = "grey50","5 year MA"="red"),
                      breaks=c("Data","5 year MA"))
ggsave('../eda_visualizations/drought/drought_moving_average_5_year.svg', plot = viz.5, width = 10, height = 6, units = 'in')

viz.20 <- autoplot(drought.ts.ca, series = 'Data') +
  autolayer(ma(drought.ts.ca, 241), series = '20 year MA') +
  ggtitle("California Droughts (20 Year Moving Average)") +
  xlab("Year (1895-2021)") +
  ylab("Drought Index") +
  scale_colour_manual(values=c("Data" = "grey50","20 year MA"="red"),
                      breaks=c("Data","20 year MA"))
ggsave('../eda_visualizations/drought/drought_moving_average_20_year.svg', plot = viz.20, width = 10, height = 6, units = 'in')

readr::write_csv(as.data.frame(tsibble::as_tsibble(drought.ts.ca)), '../cleaned_data/weather/drought_time_series.csv')