# ------------------Libraries------------------
if (!require("pacman")) {
  install.packages("pacman")
}

pacman::p_load(tidyverse, gridExtra, maps, mapdata, 
               ggthemes, mapproj, gganimate, plotly,
               aws.s3) 
# ---------------------------------------------

# ---------------------------------------------
# Weather Data
# ---------------------------------------------

weather.df <- read.csv('../cleaned_data/weather/weather_data.csv') %>% drop_na()
head(weather.df)

state_map <- map_data('state')

gif <- weather.df %>%
  mutate(year = as.integer(strftime(Date, '%Y')),
         month =  as.integer(strftime(Date, '%m')),
         day =  as.integer(strftime(Date, '%d')),
         Date = as.Date(Date)) %>%
  filter(StateAbbreviation == 'CA') %>%
  filter(month %in% c(1, 3, 5, 7, 9, 11)) %>%
  drop_na() %>%
  ggplot(aes(x = Date, y = MaxTemperature, colour = MaxTemperature)) +
  geom_line() +
  scale_color_continuous(low = "blue", 
                        high = "orange",
                        name = 'Temperature') + 
  labs(x = "Year", y = "Max Temperature", title = 'Max Temperature in California (1895-2020)') + 
  transition_reveal(Date)

animate(gif, height = 500, width = 1000, duration = 40, renderer = gifski_renderer()) # use duration to slow it down
anim_save("../cleaned_data_visualizations/weather/max_temperature_california.gif")

gif <- weather.df %>%
  mutate(year = as.integer(strftime(Date, '%Y')),
         month = as.integer(strftime(Date, '%m')),
         day = as.integer(strftime(Date, '%d')),
         Date = as.Date(Date)) %>%
  filter(StateAbbreviation == 'CA') %>%
  filter(month %in% c(1, 3, 5, 7, 9, 11)) %>%
  drop_na() %>%
  ggplot(aes(x = Date, y = MinTemperature, colour = MinTemperature)) +
  geom_line() +
  scale_color_continuous(low = "blue", 
                         high = "orange",
                         name = 'Temperature') + 
  labs(x = "Year", y = "Min Temperature", title = 'Min Temperature in California (1895-2020)') + 
  transition_reveal(Date)

animate(gif, height = 500, width = 1000, duration = 40, renderer = gifski_renderer()) # use duration to slow it down
anim_save("../cleaned_data_visualizations/weather/min_temperature_california.gif")

gif.2 <- weather.df %>% 
  mutate(region = tolower(State),
         Year = as.integer(strftime(Date, '%Y'))) %>%
  group_by(Year, region) %>%
  summarize(AverageTemperature = mean(AverageTemperature)) %>%
  right_join(state_map, by = 'region') %>%
  ggplot(aes(x = long, y = lat, group = group, fill = AverageTemperature)) + 
  geom_polygon() + 
  geom_path(color = 'white') + 
  scale_fill_continuous(low = "blue", 
                        high = "yellow",
                        name = 'Temperature') + 
  theme_map() + 
  coord_map('albers', lat0 = 30, lat1 = 40) + 
  ggtitle("Average Temperature ({1895 + frame})") + 
  theme(plot.title = element_text(hjust = 0.5)) +
  transition_manual(Year)

animate(gif.2, height = 500, width = 800, duration = 20, renderer = gifski_renderer()) # use duration to slow it down
anim_save("../cleaned_data_visualizations/weather/average_temperature_over_time.gif")

gif.3 <- weather.df %>% 
  mutate(region = tolower(State),
         Year = as.integer(strftime(Date, '%Y'))) %>%
  group_by(Year, region) %>%
  summarize(Precipitation = sum(Precipitation)) %>%
  right_join(state_map, by = 'region') %>%
  ggplot(aes(x = long, y = lat, group = group, fill = Precipitation)) + 
  geom_polygon() + 
  geom_path(color = 'white') + 
  scale_fill_continuous(low = "red", 
                        high = "green",
                        name = 'Precipitation') + 
  theme_map() + 
  coord_map('albers', lat0 = 30, lat1 = 40) + 
  ggtitle("Precipitation Totals ({1895 + frame})") + 
  theme(plot.title = element_text(hjust = 0.5)) +
  transition_manual(Year)

animate(gif.3, height = 500, width = 800, duration = 20, renderer = gifski_renderer()) # use duration to slow it down
anim_save("../cleaned_data_visualizations/weather/total_precipitation_over_time.gif")

gif.4 <- weather.df %>% 
  mutate(region = tolower(State),
         Year = as.integer(strftime(Date, '%Y'))) %>%
  group_by(Year, region) %>%
  summarize(DroughtIndex = min(DroughtIndex)) %>%
  right_join(state_map, by = 'region') %>%
  ggplot(aes(x = long, y = lat, group = group, fill = DroughtIndex)) + 
  geom_polygon() + 
  geom_path(color = 'white') + 
  scale_fill_continuous(low = "yellow", 
                        high = "blue",
                        limit = c(-8, 8),
                        name = 'Drought Index') + 
  theme_map() + 
  coord_map('albers', lat0 = 30, lat1 = 40) + 
  ggtitle("Drought Conditions ({1895 + frame})") + 
  theme(plot.title = element_text(hjust = 0.5)) +
  transition_manual(Year)

animate(gif.4, height = 500, width = 800, duration = 30, renderer = gifski_renderer()) # use duration to slow it down
anim_save("../cleaned_data_visualizations/drought/drought_over_time.gif")

viz <- weather.df %>%
  mutate(region = tolower(State),
         Year = as.integer(strftime(Date, '%Y')),
         Month = as.integer(strftime(Date, '%m')),
         Date = as.Date(Date)) %>%
  filter(StateAbbreviation == 'CA') %>%
  ggplot(aes(x = Date)) + 
  geom_line(aes(y = MinTemperature), color = "blue") + 
  geom_line(aes(y = MaxTemperature), color = "darkred") +
  labs(x = "Year", y = "Temperature (F)", title = 'Min/Max Temperature for California (1895-2020)')

png('../cleaned_data_visualizations/weather/temperature_over_time_california.png', width = 6, height = 4, units = 'in', res = 400)
print(viz)
dev.off()

htmlwidgets::saveWidget(ggplotly(viz), "../cleaned_data_visualizations/weather/temperature_over_time_california.html")

viz.1 <- weather.df %>%
  mutate(Year = as.integer(strftime(Date, '%Y')),
         Month = as.integer(strftime(Date, '%m')),
         Date = as.Date(Date)) %>%
  filter(StateAbbreviation == 'CA') %>%
  ggplot(aes(x = Date)) + 
  geom_line(aes(y = DroughtIndex), color = "orange") + 
  labs(x = "Year", y = 'Drought Index', title = 'Drought vs Precipitation in California (1895-2020)')

viz.2 <- weather.df %>%
  mutate(Year = as.integer(strftime(Date, '%Y')),
         Month = as.integer(strftime(Date, '%m')),
         Date = as.Date(Date)) %>%
  filter(StateAbbreviation == 'CA') %>%
  ggplot(aes(x = Date)) + 
  geom_line(aes(y = Precipitation), color = "blue") + 
  labs(x = "Year", y = 'Precipitation')


png('../cleaned_data_visualizations/drought/drought_precip_over_time_california.png', width = 6, height = 4, units = 'in', res = 400)
grid.arrange(viz.1, viz.2, ncol = 1)
dev.off()

ply.1 <- ggplotly(viz.1)
ply.2 <- ggplotly(viz.2)

htmlwidgets::saveWidget(subplot(ply.1, ply.2, nrows = 2), "../cleaned_data_visualizations/drought/drought_precip_over_time_california.html")


# ---------------------------------------------
# Wildfire Data
# ---------------------------------------------

wildfire.df <- read.csv('../cleaned_data/wildfire/aggregated_wildfire_data.csv') %>% drop_na()
head(wildfire.df)

gif.3 <- wildfire.df %>% 
  mutate(region = tolower(State),
         Year = as.integer(strftime(Date, '%Y'))) %>%
  group_by(Year, region) %>%
  summarize(NumberOfWildfires = sum(NumberOfWildfires)) %>%
  right_join(state_map, by = 'region') %>%
  ggplot(aes(x = long, y = lat, group = group, fill = NumberOfWildfires)) + 
  geom_polygon() + 
  geom_path(color = 'white') + 
  scale_fill_continuous(low = "beige", 
                        high = "darkred",
                        name = 'Number Of Wildfires') + 
  theme_map() + 
  coord_map('albers', lat0 = 30, lat1 = 40) + 
  ggtitle("Number of Wildfires ({1992 + frame})") + 
  theme(plot.title = element_text(hjust = 0.5)) +
  transition_manual(Year)

animate(gif.3, height = 500, width = 800, duration = 20, renderer = gifski_renderer())
anim_save("../cleaned_data_visualizations/wildfire/wildfires_over_time.gif")

gif.4 <- wildfire.df %>% 
  mutate(region = tolower(State),
         Year = as.integer(strftime(Date, '%Y'))) %>%
  filter(Year == 2010) %>%
  right_join(state_map, by = 'region') %>%
  ggplot(aes(x = long, y = lat, group = group, fill = NumberOfWildfires)) + 
  geom_polygon() + 
  geom_path(color = 'white') + 
  scale_fill_continuous(low = "beige", 
                        high = "darkred",
                        name = 'Wildfires') + 
  theme_map() + 
  coord_map('albers', lat0 = 30, lat1 = 40) + 
  ggtitle("Number of Wildfires ({month.name[frame]} 2010)") + 
  theme(plot.title = element_text(hjust = 0.5)) +
  transition_manual(Date)

animate(gif.4, height = 500, width = 800, duration = 12, renderer = gifski_renderer())
anim_save("../cleaned_data_visualizations/wildfire/wildfires_in_2010.gif")

wildfires.2015 <- wildfire.df %>%
  mutate(Year = as.integer(strftime(Date, '%Y'))) %>%
  filter(Year == 2015) %>%
  ggplot(aes(x = Date, y = NumberOfWildfires, fill = NumberOfWildfires)) +
  geom_bar(stat = "identity") +
  scale_fill_continuous(low = "orange", 
                        high = "darkred",
                        limits = c(0, 2000),
                        name = 'Wildfires') + 
  scale_y_continuous(limits = c(0, 2000)) +
  facet_wrap(~State) + 
  labs(x = "January-December 2015", y = 'Number of Wildfires', title = 'Number of Wildfires in 2015') +
  theme(axis.text.x=element_blank(),
        axis.ticks.x=element_blank())


ggsave('../cleaned_data_visualizations/wildfire/united_states_wildfires_2015.svg', width = 10, height = 6, units = 'in')
print(wildfires.2015)
dev.off()

wildfires.2005 <- wildfire.df %>%
  mutate(Year = as.integer(strftime(Date, '%Y'))) %>%
  filter(Year == 2005) %>%
  ggplot(aes(x = Date, y = NumberOfWildfires, fill = NumberOfWildfires)) +
  geom_bar(stat = "identity") +
  scale_fill_continuous(low = "orange", 
                        high = "darkred",
                        limits = c(0, 2000),
                        name = 'Wildfires') +
  scale_y_continuous(limits = c(0, 2000)) +
  facet_wrap(~State) + 
  labs(x = "January-December 2005", y = 'Number of Wildfires', title = 'Number of Wildfires in 2005') +
  theme(axis.text.x=element_blank(),
        axis.ticks.x=element_blank())


ggsave('../cleaned_data_visualizations/wildfire/united_states_wildfires_2005.svg', width = 10, height = 6, units = 'in')
print(wildfires.2005)
dev.off()

wildfires.1995 <- wildfire.df %>%
  mutate(Year = as.integer(strftime(Date, '%Y'))) %>%
  filter(Year == 1995) %>%
  ggplot(aes(x = Date, y = NumberOfWildfires, fill = NumberOfWildfires)) +
  geom_bar(stat = "identity") +
  scale_fill_continuous(low = "orange", 
                        high = "darkred",
                        limits = c(0, 2000),
                        name = 'Wildfires') +
  scale_y_continuous(limits = c(0, 2000)) +
  facet_wrap(~State) + 
  labs(x = "January-December 1995", y = 'Number of Wildfires', title = 'Number of Wildfires in 1995') +
  theme(axis.text.x=element_blank(),
        axis.ticks.x=element_blank())


ggsave('../cleaned_data_visualizations/wildfire/united_states_wildfires_1995.svg', width = 10, height = 6, units = 'in')
print(wildfires.1995)
dev.off()

viz <- wildfire.df %>%
  mutate(Date = as.Date(Date)) %>%
  filter(StateAbbreviation == 'CA') %>%
  ggplot(aes(x = Date, y = NumberOfWildfires, colour = NumberOfWildfires, group = 1)) +
  geom_line() +
  scale_color_continuous(low = "orange", 
                         high = "darkred",
                         name = 'Wildfires') + 
  labs(x = "Time (1992 - Present)", y = "Number of Wildfires", title = 'Wildfires for California')

ggsave('../cleaned_data_visualizations/wildfire/wildfires_over_time_california.svg', width = 10, height = 6, units = 'in')
print(viz)
dev.off()

viz <- wildfire.df %>%
  mutate(Date = as.Date(Date)) %>%
  filter(StateAbbreviation == 'NY') %>%
  ggplot(aes(x = Date, y = NumberOfWildfires, colour = NumberOfWildfires, group = 1)) +
  geom_line() +
  scale_color_continuous(low = "orange", 
                         high = "darkred",
                         name = 'Wildfires') + 
  labs(x = "Time (1992-Present)", y = "Number of Wildfires", title = 'Wildfires for New York')

ggsave('../cleaned_data_visualizations/wildfire/wildfires_over_time_new_york.svg', width = 10, height = 6, units = 'in')
print(viz)
dev.off()

viz <- wildfire.df %>%
  mutate(Date = as.Date(Date)) %>%
  filter(StateAbbreviation == 'SC') %>%
  ggplot(aes(x = Date, y = NumberOfWildfires, colour = NumberOfWildfires, group = 1)) +
  geom_line() +
  scale_color_continuous(low = "orange", 
                         high = "darkred",
                         name = 'Wildfires') + 
  labs(x = "Time (1992-Present)", y = "Number of Wildfires", title = 'Wildfires for South Carolina')

ggsave('../cleaned_data_visualizations/wildfire/wildfires_over_time_south_carolina.svg', width = 10, height = 6, units = 'in')
print(viz)
dev.off()


# ---------------------------------------------
# Flood Data
# ---------------------------------------------

flood.df <- read.csv('../cleaned_data/floods/aggregated_flood_data.csv') %>% drop_na()
head(flood.df)

gif.3 <- flood.df %>% 
  mutate(region = tolower(State),
         Year = as.integer(strftime(Date, '%Y'))) %>%
  group_by(Year, region) %>%
  summarize(NumberOfFloods = sum(NumberOfFloods)) %>%
  right_join(state_map, by = 'region') %>%
  ggplot(aes(x = long, y = lat, group = group, fill = NumberOfFloods)) + 
  geom_polygon() + 
  geom_path(color = 'white') + 
  scale_fill_continuous(low = "beige", 
                        high = "darkblue",
                        name = 'Floods') + 
  theme_map() + 
  coord_map('albers', lat0 = 30, lat1 = 40) + 
  ggtitle("Number of Floods ({2006 + frame})") + 
  theme(plot.title = element_text(hjust = 0.5)) +
  transition_manual(Year)

animate(gif.3, height = 500, width = 800, duration = 20, renderer = gifski_renderer())
anim_save("../cleaned_data_visualizations/floods/floods_over_time.gif")

gif.4 <- flood.df %>% 
  mutate(region = tolower(State),
         Year = as.integer(strftime(Date, '%Y'))) %>%
  filter(Year == 2016) %>%
  right_join(state_map, by = 'region') %>%
  ggplot(aes(x = long, y = lat, group = group, fill = NumberOfFloods)) + 
  geom_polygon() + 
  geom_path(color = 'white') + 
  scale_fill_continuous(low = "beige", 
                        high = "darkblue",
                        name = 'Floods') + 
  theme_map() + 
  coord_map('albers', lat0 = 30, lat1 = 40) + 
  ggtitle("Number of Floods ({month.name[frame]} 2016)") + 
  theme(plot.title = element_text(hjust = 0.5)) +
  transition_manual(Date)

animate(gif.4, height = 500, width = 800, duration = 12, renderer = gifski_renderer())
anim_save("../cleaned_data_visualizations/floods/floods_in_2016.gif")

floods.2016 <- flood.df %>%
  mutate(Year = as.integer(strftime(Date, '%Y'))) %>%
  filter(Year == 2016) %>%
  ggplot(aes(x = Date, y = NumberOfFloods, fill = NumberOfFloods)) +
  geom_bar(stat = "identity") +
  scale_fill_continuous(low = "lightblue", 
                        high = "darkblue",
                        limits = c(0, 200),
                        name = 'Floods') + 
  scale_y_continuous(limits = c(0, 200)) +
  facet_wrap(~State) + 
  labs(x = "January-December 2016", y = 'Number of Floods', title = 'Number of Floods in 2016') +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank())


ggsave('../cleaned_data_visualizations/floods/united_states_floods_2016.svg', width = 10, height = 6, units = 'in')
print(floods.2016)
dev.off()

floods.2008 <- flood.df %>%
  mutate(Year = as.integer(strftime(Date, '%Y'))) %>%
  filter(Year == 2008) %>%
  ggplot(aes(x = Date, y = NumberOfFloods, fill = NumberOfFloods)) +
  geom_bar(stat = "identity") +
  scale_fill_continuous(low = "lightblue", 
                        high = "darkblue",
                        limits = c(0, 200),
                        name = 'Floods') + 
  scale_y_continuous(limits = c(0, 200)) +
  facet_wrap(~State) + 
  labs(x = "January-December 2008", y = 'Number of Floods', title = 'Number of Floods in 2008') +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank())


ggsave('../cleaned_data_visualizations/floods/united_states_floods_2008.svg', width = 10, height = 6, units = 'in')
print(floods.2008)
dev.off()

floods.2012 <- flood.df %>%
  mutate(Year = as.integer(strftime(Date, '%Y'))) %>%
  filter(Year == 2012) %>%
  ggplot(aes(x = Date, y = NumberOfFloods, fill = NumberOfFloods)) +
  geom_bar(stat = "identity") +
  scale_fill_continuous(low = "lightblue", 
                        high = "darkblue",
                        limits = c(0, 200),
                        name = 'Floods') + 
  scale_y_continuous(limits = c(0, 200)) +
  facet_wrap(~State) + 
  labs(x = "January-December 2012", y = 'Number of Floods', title = 'Number of Floods in 2012') +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank())


ggsave('../cleaned_data_visualizations/floods/united_states_floods_2012.svg', width = 10, height = 6, units = 'in')
print(floods.2012)
dev.off()

viz <- flood.df %>%
  mutate(Date = as.Date(Date)) %>%
  filter(StateAbbreviation == 'IN') %>%
  ggplot(aes(x = Date, y = NumberOfFloods, colour = NumberOfFloods, group = 1)) +
  geom_line() +
  scale_color_continuous(low = "lightblue", 
                         high = "darkblue",
                         name = 'Floods') + 
  labs(x = "Time (2006-Present)", y = "Number of Floods", title = 'Floods in Indiana')

ggsave('../cleaned_data_visualizations/floods/floods_over_time_indiana.svg', width = 10, height = 6, units = 'in')
print(viz)
dev.off()

viz <- flood.df %>%
  mutate(Date = as.Date(Date)) %>%
  filter(StateAbbreviation == 'TX') %>%
  ggplot(aes(x = Date, y = NumberOfFloods, colour = NumberOfFloods, group = 1)) +
  geom_line() +
  scale_color_continuous(low = "lightblue", 
                         high = "darkblue",
                         name = 'Floods') + 
  labs(x = "Time (2006-Present)", y = "Number of Floods", title = 'Floods in Texas')

ggsave('../cleaned_data_visualizations/floods/floods_over_time_texas.svg', width = 10, height = 6, units = 'in')
print(viz)
dev.off()

viz.2 <- flood.df %>%
  mutate(Date = as.Date(Date)) %>%
  filter(StateAbbreviation == 'CA') %>%
  ggplot(aes(x = Date, y = NumberOfFloods, color = NumberOfFloods)) +
  geom_line() +
  scale_color_continuous(low = "lightblue", 
                         high = "darkblue",
                         name = 'Floods') + 
  labs(x = "Time (2006-Present)", y = "Number of Floods", title = 'Floods in California')

ggsave('../cleaned_data_visualizations/floods/floods_over_time_california.svg', width = 10, height = 6, units = 'in')
print(viz.2)
dev.off()

viz.3 <- flood.df %>%
  mutate(Date = as.Date(Date)) %>%
  filter(StateAbbreviation == 'TX') %>%
  ggplot(aes(x = Date, y = NumberOfFloods, group = 1)) +
  geom_line(color = 'blue') +
  labs(x = "Time (2006-Present)", y = "Number of Floods", title = 'Floods in Texas')

htmlwidgets::saveWidget(ggplotly(viz.3), "../cleaned_data_visualizations/floods/floods_over_time_texas.html")
