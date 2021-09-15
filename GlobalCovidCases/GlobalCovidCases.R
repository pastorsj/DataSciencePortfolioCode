# Global Covid Cases 
library(dplyr)
library(tools)
library(tidyverse)

basePath = 'raw_data'
processedDataPath = 'processed_data/'
start <- as.Date("01-22-2020",format="%m-%d-%y")
todaysDate <- as.Date(Sys.Date(),format="%m-%d-%y")
base_url <- 'https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_daily_reports/'
country <- 'Australia.csv'

getAllData <- FALSE
processAllData <- FALSE
visualizeData <- TRUE

processRow <- function (row) {
  country <- row[1]
  date <- row[3]
  fileName = paste(processedDataPath, country, '.csv', sep = '')
  # if there is a csv file that exists with the country.region name, open it into a dataframe, else create a new one
  if (file.exists(fileName)) {
    df <- rbind(read.csv(fileName), t(row))
    write.csv(df, fileName, row.names = FALSE)
  } else {
    df <- data.frame(t(row), row.names = NULL)
    write.csv(df, file = fileName, row.names = FALSE)
  }
}


processCovidData <- function(df, formattedDate) {
  # Preprocess and save again into another R datasource, this time by country
  # for each country in the df
  
  colnames(df)[which(names(df) == 'Country/Region')] <- 'Country.Region'
  colnames(df)[which(names(df) == 'Country_Region')] <- 'Country.Region'
  
  groupedByCountry <- df %>% 
    filter(!is.na(Confirmed)) %>%
    group_by(Country = Country.Region) %>%
    summarize(Confirmed = sum(Confirmed, na.rm = TRUE), Date = formattedDate)
  
    apply(groupedByCountry, 1, processRow)
  
  print('Processed date')
  print(formattedDate)
}

if (getAllData) {
  print('Getting all data')
  unlink("raw_data/*")
  theDate <- start
  while (theDate < todaysDate) {
    formattedDate = format(theDate,"%m-%d-%Y")
    url <- paste(base_url, formattedDate, '.csv', sep = '')
    df <- read.csv(url)
    # Once read, save raw data file into csv
    write.csv(df, file = paste(basePath, '/', formattedDate, '.csv', sep = ''), row.names = FALSE)
    print(url)
    theDate <- theDate + 1
  }
}
if (processAllData) {
  print('Processing all data')
  unlink("processed_data/*")
  allFiles = list.files(basePath, full.names = TRUE)
  lapply(allFiles, FUN = function(f) { processCovidData(read.csv(f), file_path_sans_ext(basename(f))) })
}
if (visualizeData) {
  print('Visualizing global covid data for a country')
  df <- read.csv(paste(processedDataPath, country, sep = ''))
  df$Confirmed = as.numeric(df$Confirmed)
  df$Date = as.Date(df$Date, format =  "%m-%d-%Y")
  print(head(df))
  print(str(df))
  
  p <- ggplot(df, aes(x = Date, y = Confirmed, group = 1)) +
    geom_line(color="#69b3a2", size = 2) +
    labs(x = "Date", y = "Confirmed Cases", 
         title = "Covid Cases in Austrailia")
    ggtitle("Covid Cases in Austrailia")
  print(p)
}
