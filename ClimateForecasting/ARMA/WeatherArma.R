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

acf(diff(temperature.ts.ca, 12), main = "ACF of Average Temperature in California Time Series")
pacf(diff(temperature.ts.ca, 12), main = "PACF of Average Temperature in California Time Series")
