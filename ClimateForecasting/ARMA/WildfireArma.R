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