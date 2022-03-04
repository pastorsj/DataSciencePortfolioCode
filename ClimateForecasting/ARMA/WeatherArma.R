# ------------------Libraries------------------
if (!require("pacman")) {
  install.packages("pacman")
}

pacman::p_load(
  tidyverse,
  gridExtra,
  TSstudio,
  fpp,
  forecast,
  astsa,
  lubridate,
  zoo
)
# ---------------------------------------------

weather.df <-
  read.csv("../cleaned_data/weather/weather_data.csv") %>% drop_na()
head(weather.df)

temperature.ts.ca <- weather.df %>%
  filter(StateAbbreviation == "CA") %>%
  select(AverageTemperature) %>%
  ts(
    start = c(1895, 1),
    end = c(2021, 12),
    frequency = 12
  )

autoplot(temperature.ts.ca) +
  ggtitle("Average Temperature in California") +
  xlab("Year (1895-2021)") +
  ylab("Average Temperature")

ggAcf(diff(temperature.ts.ca, 12)) +
  ggtitle("ACF of Average Temperature in California") #q=1-2
ggsave('../arma_visualizations/weather/temperature_stationary_acf_plot.svg', width = 8, height = 6, units = 'in')

png('../arma_visualizations/weather/temperature_stationary_pacf_plot.png', width = 8, height = 6, units = 'in', res = 400)
pacf(diff(temperature.ts.ca, 12), main = 'PACF of Average Temperature in California')#p=1-2
dev.off()
