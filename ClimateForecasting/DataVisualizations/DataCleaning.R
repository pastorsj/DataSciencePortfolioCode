# ------------------Libraries------------------
if (!require("pacman")) {
  install.packages("pacman")
}

pacman::p_load(tidyverse, gridExtra, maps) 
# ---------------------------------------------

climate.div.states <- c('Alabama', 'Arizona', 'Arkansas', 'California', 
                           'Colorado', 'Connecticut', 'Delaware', 'Florida', 
                           'Georgia', 'Idaho', 'Illinois', 'Indiana', 'Iowa', 
                           'Kansas', 'Kentucky', 'Louisiana', 'Maine', 
                           'Maryland', 'Massachusetts', 'Michigan', 'Minnesota', 
                           'Mississippi', 'Missouri', 'Montana', 'Nebraska', 
                           'Nevada', 'New Hampshire', 'New Jersey', 'New Mexico', 
                           'New York', 'North Carolina', 'North Dakota', 'Ohio', 
                           'Oklahoma', 'Oregon', 'Pennsylvania', 'Rhode Island', 
                           'South Carolina', 'South Dakota', 'Tennessee', 'Texas', 
                           'Utah', 'Vermont', 'Virginia', 'Washington', 
                           'West Virginia', 'Wisconsin', 'Wyoming', 'Alaska')

climate.div.states.num <- c('1', '2', '3', '4', '5', '6', '7', '8', '9', '10', 
                            '11', '12', '13', '14', '15', '16', '17', '18', '19', 
                            '20', '21', '22', '23', '24', '25', '26', '27', '28', 
                            '29', '30', '31', '32', '33', '34', '35', '36', '37', 
                            '38', '39', '40', '41', '42', '43', '44', '45', '46', 
                            '47', '48', '50')

climate.div.states.df <- data.frame(Number = as.numeric(climate.div.states.num), 
                                    State = climate.div.states)



#' Creates a directory if it does not exist yet
#' 
#' @param path A path to create
#' @examples 
#' createDirectoryIfNotExists('path/to/file')
createDirectoryIfNotExists <- function(path) {
  # Create the directory if it doesn't exist.
  if (dir.exists(path) == FALSE) {
    dir.create(path, recursive = TRUE)
  }
}


createDirectoryIfNotExists('../cleaned_data/weather')
createDirectoryIfNotExists('../cleaned_data/floods')
createDirectoryIfNotExists('../cleaned_data/wildfire')
createDirectoryIfNotExists('../eda_visualizations/weather')
createDirectoryIfNotExists('../eda_visualizations/floods')
createDirectoryIfNotExists('../eda_visualizations/wildfire')
createDirectoryIfNotExists('../eda_visualizations/drought')
createDirectoryIfNotExists('../cleaned_data_visualizations/weather')
createDirectoryIfNotExists('../cleaned_data_visualizations/floods')
createDirectoryIfNotExists('../cleaned_data_visualizations/drought')
createDirectoryIfNotExists('../cleaned_data_visualizations/wildfire')
createDirectoryIfNotExists('../arma_visualizations/weather')
createDirectoryIfNotExists('../arma_visualizations/floods')
createDirectoryIfNotExists('../arma_visualizations/drought')
createDirectoryIfNotExists('../arma_visualizations/wildfire')
createDirectoryIfNotExists('../arma_data/weather')
createDirectoryIfNotExists('../arma_data/floods')
createDirectoryIfNotExists('../arma_data/drought')
createDirectoryIfNotExists('../arma_data/wildfire')
createDirectoryIfNotExists('../arch_data/price')
createDirectoryIfNotExists('../arch_visualizations/price')


# Let's clean the drought data
drought.index <- read.csv('../raw_data/noaa/climate_division/climdiv-pdsist-v1.0.0-20220108_data.csv')

cleaned.drought.df <- drought.index %>%
  filter(State %in% climate.div.states.df$Number)

cleaned.drought.df$State <- lapply(cleaned.drought.df$State, FUN = function(x) climate.div.states.df[climate.div.states.df$Number == x,]$State[1])
cleaned.drought.df$State <- as.factor(as.character(cleaned.drought.df$State))

cleaned.drought.df <- cleaned.drought.df %>%
  pivot_longer(-c('State', 'Division', 'Element', 'Year'), names_to = 'Month', values_to = 'DroughtIndex') %>%
  mutate(Date = as.Date(paste(Month, '01', Year, sep = '-'), format = '%B-%d-%Y'),
         DroughtStatus = cut(x = DroughtIndex,
                             breaks = c(-8, -2.75, -2, -1.25, 1, 2.5, 3.5, 8), 
                             labels = c('Extreme Drought', 'Severe Drought', 'Mild to Moderate Drought', 
                                        'Near Normal', 'Mild to Moderate Wetness', 'Severe Wetness', 
                                        'Extreme Wetness'))) %>%
  select(State, Date, DroughtStatus, DroughtIndex)

# Let's clean the precipitation data
precip.index <- read.csv('../raw_data/noaa/climate_division/climdiv-pcpnst-v1.0.0-20220108_data.csv')

cleaned.precip.df <- precip.index %>%
  filter(State %in% climate.div.states.df$Number)

cleaned.precip.df$State <- lapply(cleaned.precip.df$State, FUN = function(x) climate.div.states.df[climate.div.states.df$Number == x,]$State[1])
cleaned.precip.df$State <- as.factor(as.character(cleaned.precip.df$State))

cleaned.precip.df <- cleaned.precip.df %>%
  pivot_longer(-c('State', 'Division', 'Element', 'Year'), names_to = 'Month', values_to = 'Precipitation') %>%
  mutate(Date = as.Date(paste(Month, '01', Year, sep = '-'), format = '%B-%d-%Y')) %>%
  select(State, Date, Precipitation)

# Combine the data together
cleaned.df <- merge(x = cleaned.drought.df, y = cleaned.precip.df, by = c('State', 'Date'), all = TRUE)

# Let's clean and combine the temperature data
temp.index <- read.csv('../raw_data/noaa/climate_division/climdiv-tmpcst-v1.0.0-20220108_data.csv')

cleaned.temp.df <- temp.index %>%
  filter(State %in% climate.div.states.df$Number)

cleaned.temp.df$State <- lapply(cleaned.temp.df$State, FUN = function(x) climate.div.states.df[climate.div.states.df$Number == x,]$State[1])
cleaned.temp.df$State <- as.factor(as.character(cleaned.temp.df$State))

cleaned.temp.df <- cleaned.temp.df %>%
  pivot_longer(-c('State', 'Division', 'Element', 'Year'), names_to = 'Month', values_to = 'AverageTemperature') %>%
  mutate(Date = as.Date(paste(Month, '01', Year, sep = '-'), format = '%B-%d-%Y')) %>%
  select(State, Date, AverageTemperature)

cleaned.df <- merge(x = cleaned.df, y = cleaned.temp.df, by = c('State', 'Date'), all = TRUE)

# Let's clean and combine the max temperature data
max.temp.index <- read.csv('../raw_data/noaa/climate_division/climdiv-tmaxst-v1.0.0-20220108_data.csv')

cleaned.max.temp.df <- max.temp.index %>%
  filter(State %in% climate.div.states.df$Number)

cleaned.max.temp.df$State <- lapply(cleaned.max.temp.df$State, FUN = function(x) climate.div.states.df[climate.div.states.df$Number == x,]$State[1])

cleaned.max.temp.df <- cleaned.max.temp.df %>%
  pivot_longer(-c('State', 'Division', 'Element', 'Year'), names_to = 'Month', values_to = 'MaxTemperature') %>%
  mutate(Date = as.Date(paste(Month, '01', Year, sep = '-'), format = '%B-%d-%Y')) %>%
  select(State, Date, MaxTemperature)

cleaned.df <- merge(x = cleaned.df, y = cleaned.max.temp.df, by = c('State', 'Date'), all = TRUE)

# Let's clean and combine the min temperature data
min.temp.index <- read.csv('../raw_data/noaa/climate_division/climdiv-tminst-v1.0.0-20220108_data.csv')

cleaned.min.temp.df <- min.temp.index %>%
  filter(State %in% climate.div.states.df$Number)

cleaned.min.temp.df$State <- lapply(cleaned.min.temp.df$State, FUN = function(x) climate.div.states.df[climate.div.states.df$Number == x,]$State[1])
cleaned.min.temp.df$State <- as.factor(as.character(cleaned.min.temp.df$State))

cleaned.min.temp.df <- cleaned.min.temp.df %>%
  pivot_longer(-c('State', 'Division', 'Element', 'Year'), names_to = 'Month', values_to = 'MinTemperature') %>%
  mutate(Date = as.Date(paste(Month, '01', Year, sep = '-'), format = '%B-%d-%Y')) %>%
  select(State, Date, MinTemperature)

cleaned.df <- merge(x = cleaned.df, y = cleaned.min.temp.df, by = c('State', 'Date'), all = TRUE)

cleaned.df$StateAbbreviation <- as.factor(state.abb[match(cleaned.df$State,state.name)])
capitals <- us.cities[us.cities$capital == 2,]
cleaned.df$Longitude <- capitals[match(cleaned.df$StateAbbreviation, capitals$country.etc),]$long
cleaned.df$Latitude <- capitals[match(cleaned.df$StateAbbreviation, capitals$country.etc),]$lat
cleaned.df <- cleaned.df[, c(2,1,9,4,3,5,6,7,8,10,11)]
write.csv(cleaned.df, '../cleaned_data/weather/weather_data.csv', row.names = FALSE)

print(str(cleaned.df))
print(dim(cleaned.df))


# Let's clean wildfire data
wildfire.data <- read.csv('../raw_data/usda/wildfire_data.csv')
print(str(wildfire.data))

cleaned.wildfire.df <- wildfire.data %>%
  select(DISCOVERY_DATE, CONT_DATE, STATE, LATITUDE, LONGITUDE, FIRE_SIZE) %>%
  filter(STATE %in% state.abb) %>%
  rename(StateAbbreviation = STATE,
         Latitude = LATITUDE,
         Longitude = LONGITUDE,
         DiscoveryDate = DISCOVERY_DATE,
         ContainedDate = CONT_DATE,
         FireSize = FIRE_SIZE) %>%
  mutate(State = as.factor(state.name[match(StateAbbreviation, state.abb)]),
         StateAbbreviation = as.factor(StateAbbreviation))

cleaned.wildfire.df <- cleaned.wildfire.df[, c(1,2,7,3,4,5,6)]

print(str(cleaned.wildfire.df))
print(head(cleaned.wildfire.df))
write.csv(cleaned.wildfire.df, '../cleaned_data/wildfire/wildfire_data.csv', row.names = FALSE)

# Aggregate wildfire data by state, month and year
agg.wildfire.df <- cleaned.wildfire.df %>%
  mutate(Year = strftime(DiscoveryDate, '%Y'),
         Month = strftime(DiscoveryDate, '%m'),
         Count = 1) %>%
  group_by(StateAbbreviation, Year, Month) %>%
  summarize(AverageWildfireSize = mean(FireSize),
            NumberOfWildfires = sum(Count)) %>%
  mutate(Date = as.Date(paste(Month, '01', Year, sep = '-'), format = '%m-%d-%Y'),
         State = as.factor(state.name[match(StateAbbreviation, state.abb)]),
         StateAbbreviation = as.factor(StateAbbreviation),
         Year = as.numeric(Year)) %>%
  select(Date, State, StateAbbreviation, AverageWildfireSize, NumberOfWildfires)

date.df <- data.frame(Date = seq(as.Date('1992-01-01'), by = 'month', length.out = 12*24))
state.df <- data.frame(StateAbbreviation = state.abb)
cleaned.agg.wildfire.df <- merge(date.df, state.df, by = NULL)
cleaned.agg.wildfire.df <- merge(cleaned.agg.wildfire.df, agg.wildfire.df, by = c('StateAbbreviation', 'Date'), all = TRUE) %>%
  select(-Year) %>%
  replace_na(list(AverageWildfireSize = 0,
                  NumberOfWildfires = 0)) %>%
  mutate(State = as.factor(state.name[match(StateAbbreviation, state.abb)]),
         StateAbbreviation = as.factor(StateAbbreviation))

cleaned.agg.wildfire.df <- cleaned.agg.wildfire.df[, c(2,3,1,4,5)]

print(head(cleaned.agg.wildfire.df))
print(str(cleaned.agg.wildfire.df))
write.csv(cleaned.agg.wildfire.df, '../cleaned_data/wildfire/aggregated_wildfire_data.csv', row.names = FALSE)

# Let's clean flood data
flood.data <- read.csv('../raw_data/flood/flood_data.csv')
print(str(flood.data))

cleaned.flood.df <- flood.data %>%
  select(begin_date_time, end_date_time, state) %>%
  rename(State = state,
         DiscoveryDate = begin_date_time,
         ContainedDate = end_date_time) %>%
  mutate(StateAbbreviation = as.factor(state.abb[match(tolower(State), tolower(state.name))])) %>%
  mutate(State = as.factor(state.name[match(tolower(StateAbbreviation), tolower(state.abb))])) %>%
  filter(!is.na(State)) %>%
  separate(DiscoveryDate, c("DiscoveryDate", "DiscoveryTime"), " ") %>%
  separate(ContainedDate, c("ContainedDate", "ContainedTime"), " ") %>%
  select(-DiscoveryTime, -ContainedTime) %>%
  mutate(DiscoveryDate = as.Date(DiscoveryDate, format = '%m/%d/%Y'),
         ContainedDate = as.Date(ContainedDate, format = '%m/%d/%Y'))

print(str(cleaned.flood.df))
print(head(cleaned.flood.df))
write.csv(cleaned.flood.df, '../cleaned_data/floods/flood_data.csv', row.names = FALSE)

# Let's aggregate the flood data
agg.flood.df <- cleaned.flood.df %>%
  mutate(Year = strftime(DiscoveryDate, '%Y'),
         Month = strftime(DiscoveryDate, '%m',),
         Count = 1) %>%
  group_by(StateAbbreviation, Year, Month) %>%
  summarize(NumberOfFloods = sum(Count)) %>%
  mutate(Date = as.Date(paste(Month, '01', Year, sep = '-'), format = '%m-%d-%Y'),
         State = as.factor(state.name[match(StateAbbreviation, state.abb)]),
         StateAbbreviation = as.factor(StateAbbreviation),
         Year = as.numeric(Year)) %>%
  select(Date, State, StateAbbreviation, NumberOfFloods)
  
flood.date.df <- data.frame(Date = seq(as.Date('2006-01-01'), by = 'month', length.out = 12*16))
cleaned.agg.flood.df <- merge(flood.date.df, state.df, by = NULL)
cleaned.agg.flood.df <- merge(cleaned.agg.flood.df, agg.flood.df, by = c('StateAbbreviation', 'Date'), all = TRUE) %>%
  select(-Year) %>%
  replace_na(list(NumberOfFloods = 0)) %>%
  mutate(State = as.factor(state.name[match(StateAbbreviation, state.abb)]),
         StateAbbreviation = as.factor(StateAbbreviation))

cleaned.agg.flood.df <- cleaned.agg.flood.df[, c(2,3,1,4)]

print(head(cleaned.agg.flood.df))
print(str(cleaned.agg.flood.df))
write.csv(cleaned.agg.flood.df, '../cleaned_data/floods/aggregated_flood_data.csv', row.names = FALSE)
