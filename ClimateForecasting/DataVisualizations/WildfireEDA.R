# ------------------Libraries------------------
if (!require("pacman")) {
  install.packages("pacman")
}

pacman::p_load(tidyverse, gridExtra, TSstudio, 
               fpp, forecast, astsa, lubridate, 
               zoo, fpp) 
# ---------------------------------------------

wildfire.df <- read.csv('../cleaned_data/wildfire/aggregated_wildfire_data.csv') %>% drop_na()
head(wildfire.df)

# Start with California
wildfire.ts.ca <- wildfire.df %>%
  filter(StateAbbreviation == 'CA') %>%
  select(NumberOfWildfires) %>%
  ts(start = c(1992, 1), end = c(2015, 12), frequency = 12)

png('../eda_visualizations/wildfire/basic_time_series_wildfires.png', width = 8, height = 6, units = 'in', res = 400)
plot(wildfire.ts.ca, xlab = "Year (1992-2016)", ylab = 'Number of Wildfires', main = 'California Wildfires')
dev.off()

# Plot the data
viz <- autoplot(wildfire.ts.ca) +
  ggtitle("California Wildfires") +
  xlab("Year (1992-2016)") +
  ylab("Number of Wildfires")

ggsave('../eda_visualizations/wildfire/wildfire_time_series.svg', width = 10, height = 6, units = 'in')
print(viz)
dev.off()

html.viz <- ts_plot(wildfire.ts.ca, 
                    Xtitle = "Year (1992-2016)", 
                    Ytitle = 'Number of Wildfires', 
                    title = 'California Wildfires')
htmlwidgets::saveWidget(html.viz, "../eda_visualizations/wildfire/wildfire_time_series.html")


# Lag Plots
viz <- gglagplot(wildfire.ts.ca, do.lines = FALSE) +
  ggtitle("Lag Plots of California Wildfires")

ggsave('../eda_visualizations/wildfire/wildfire_lag_plots.svg', width = 8, height = 8, units = 'in')
print(viz)
dev.off()


# Interactive Lag Plots
html.viz <- ts_lags(wildfire.ts.ca)
htmlwidgets::saveWidget(html.viz, "../eda_visualizations/wildfire/wildfire_lag_plots.html")

# Interactive Seasonality Plots
html.viz <- ts_seasonal(wildfire.ts.ca, type = 'all', title = 'Seasonality Plot of California Wildfires')
htmlwidgets::saveWidget(html.viz, "../eda_visualizations/wildfire/wildfire_seasonality.html")

html.viz <- ts_heatmap(wildfire.ts.ca, title = 'Seasonality Heatmap of California Wildfires')
htmlwidgets::saveWidget(html.viz, "../eda_visualizations/wildfire/")

# Take a look at the trend
wildfire.trend <- ma(wildfire.ts.ca, order = 12, centre = T)
png('../eda_visualizations/wildfire/trended_time_series_wildfires.png')
plot(wildfire.ts.ca, xlab = "Year (1992-2016)", ylab = 'Number of Wildfires', main = 'California Wildfires')
lines(wildfire.trend)
dev.off()

# Try additive
wildfire.decomp <- decompose(wildfire.ts.ca, "additive")
viz <- autoplot(wildfire.decomp) +
  ggtitle("Decomposition of California Wildfires Time Series") +
  xlab("Year (1992-2016)")

ggsave('../eda_visualizations/wildfire/decomposition_wildfires.svg', width = 10, height = 6, units = 'in')
print(viz)
dev.off()

# Try STL approach
wildfire.stl <- stl(wildfire.ts.ca[, 1], s.window = 'periodic')
autoplot(wildfire.stl) # Almost exactly the same output as above

# Take a look at the ACF and PACF graphs
png('../eda_visualizations/wildfire/basic_wildfire_acf_plot.png', width = 8, height = 6, units = 'in', res = 400)
acf(wildfire.ts.ca, main = 'ACF of California Wildfires Time Series')
dev.off()

png('../eda_visualizations/wildfire/basic_wildfire_pacf_plot.png', width = 8, height = 6, units = 'in', res = 400)
pacf(wildfire.ts.ca, main = 'PACF of California Wildfires Time Series')
dev.off()

acf.1 <- ggAcf(wildfire.ts.ca) +
  ggtitle("ACF of California Wildfires Time Series")
acf.2 <- ggAcf(wildfire.ts.ca - wildfire.decomp$seasonal) +
  ggtitle("ACF of California Wildfires Time Series (Remove Seasonal)")

png('../eda_visualizations/wildfire/combined_wildfire_acf_plots.png', width = 10, height = 8, units = 'in', res = 400)
grid.arrange(acf.1, acf.2, ncol = 1)
dev.off()

# Confirm stationarity using Augmented Dickey Fuller Test
tseries::adf.test(wildfire.ts.ca)

# Final plot of ACF after diff
ggsave('../eda_visualizations/wildfire/wildfire_stationary_acf_plot.svg', width = 8, height = 6, units = 'in')
ggAcf(wildfire.ts.ca - wildfire.decomp$seasonal)
dev.off()

# Moving Average Smoothing
viz.2 <- autoplot(wildfire.ts.ca, series = 'Data') +
  autolayer(ma(wildfire.ts.ca, 5), series = '4 month MA') +
  ggtitle("California Wildfires (4 Year Moving Average)") +
  xlab("Year (1992-2016)") +
  ylab("Number of Wildfires") +
  scale_colour_manual(values=c("Data" = "grey50","4 month MA"="red"),
                      breaks=c("Data","4 month MA"))
ggsave('../eda_visualizations/wildfire/wildfire_moving_average_4_month.svg', plot = viz.2, width = 10, height = 6, units = 'in')

viz.1 <- autoplot(wildfire.ts.ca, series = 'Data') +
  autolayer(ma(wildfire.ts.ca, 13), series = '1 year MA') +
  ggtitle("California Wildfires (1 Year Moving Average)") +
  xlab("Year (1992-2016)") +
  ylab("Number of Wildfires") +
  scale_colour_manual(values=c("Data" = "grey50","1 year MA"="red"),
                      breaks=c("Data","1 year MA"))
ggsave('../eda_visualizations/wildfire/wildfire_moving_average_1_year.svg', plot = viz.1, width = 10, height = 6, units = 'in')

viz.3 <- autoplot(wildfire.ts.ca, series = 'Data') +
  autolayer(ma(wildfire.ts.ca, 37), series = '3 year MA') +
  ggtitle("California Wildfires (3 Year Moving Average)") +
  xlab("Year (1992-2016)") +
  ylab("Number of Wildfires") +
  scale_colour_manual(values=c("Data" = "grey50","3 year MA"="red"),
                      breaks=c("Data","3 year MA"))
ggsave('../eda_visualizations/wildfire/wildfire_moving_average_3_year.svg', plot = viz.3, width = 10, height = 6, units = 'in')

viz.5 <- autoplot(wildfire.ts.ca, series = 'Data') +
  autolayer(ma(wildfire.ts.ca, 61), series = '5 year MA') +
  ggtitle("California Wildfires (5 Year Moving Average)") +
  xlab("Year (1992-2016)") +
  ylab("Number of Wildfires") +
  scale_colour_manual(values=c("Data" = "grey50","5 year MA"="red"),
                      breaks=c("Data","5 year MA"))
ggsave('../eda_visualizations/wildfire/wildfire_moving_average_5_year.svg', plot = viz.5, width = 10, height = 6, units = 'in')

readr::write_csv(as.data.frame(tsibble::as_tsibble(wildfire.ts.ca)), '../cleaned_data/wildfire/wildfire_time_series.csv')