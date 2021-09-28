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
statesPlusDC <- c(state.name, 'District of Columbia')
stateAbbrPlusDC <- c(state.abb, 'DC')

getAllData <- FALSE
processAllData <- TRUE
visualizeData <- FALSE

processRow <- function (row) {
  country <- row[1]
  date <- row[3]
  fileName = paste(processedDataPath, country, '.csv', sep = '')
  # if there is a csv file that exists with the country.region name, open it into a dataframe, else create a new one
  if (file.exists(fileName)) {
    csv <- read.csv(fileName)
    trow <- t(row)
    df <- rbind(csv, trow)
    write.csv(df, fileName, row.names = FALSE)
  } else {
    df <- data.frame(t(row), row.names = NULL)
    write.csv(df, file = fileName, row.names = FALSE)
  }
}


processGlobalCovidData <- function(df, formattedDate) {
  # Preprocess and save again into another R datasource, this time by country
  # for each country in the df
  
  colnames(df)[which(names(df) == 'Country/Region')] <- 'Country.Region'
  colnames(df)[which(names(df) == 'Country_Region')] <- 'Country.Region'
  
  groupedByCountry <- df %>% 
    filter(!is.na(Confirmed)) %>%
    group_by(Country = Country.Region) %>%
    summarize(Confirmed = sum(Confirmed, na.rm = TRUE), Date = formattedDate)
  
  apply(groupedByCountry, 1, processRow)
  
  print('Processed global covid data for date')
  print(formattedDate)
}

cleanStates <- function(sts) {
  resultingStates <- character()
  for (s in sts) {  
    if(grepl(', ', s)) {
      cleanedState <- str_replace(s, fixed('(From Diamond Princess)'), '')
      cleanedState <- str_replace(cleanedState, fixed('D.C.'), 'DC')
      fullStateName <- statesPlusDC[stateAbbrPlusDC == str_trim(unlist(strsplit(cleanedState, ',')))[2]]
      if (length(fullStateName) != 0) {
        resultingStates <- append(resultingStates, fullStateName)
      } else {
        resultingStates <- append(resultingStates, 'NA')
      }
    }  else {
      resultingStates <- append(resultingStates, s)
    }
  }
  return(resultingStates)
}

processUSCovidData <- function(df, formattedDate) {
  # Preprocess and save again into another R datasource, this time by country
  # for each country in the df
  print('Grouping by state')
  print(formattedDate)
  
  colnames(df)[which(names(df) == 'Country/Region')] <- 'Country.Region'
  colnames(df)[which(names(df) == 'Country_Region')] <- 'Country.Region'
  colnames(df)[which(names(df) == 'Province/State')] <- 'Province.State'
  colnames(df)[which(names(df) == 'Province_State')] <- 'Province.State'
  
  groupedByState <- df %>% 
    filter(!is.na(Confirmed)) %>%
    filter(Country.Region == 'US') %>%
    mutate(Province.State = cleanStates(Province.State)) %>%
    group_by(State = Province.State) %>%
    filter(Province.State %in% statesPlusDC) %>%
    summarize(Confirmed = sum(Confirmed, na.rm = TRUE), Date = formattedDate)
  
  apply(groupedByState, 1, processRow)
  
  print('Processed us state covid data for date')
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
  print('Processing state data!')
  lapply(allFiles, FUN = function(f) { processUSCovidData(read.csv(f), file_path_sans_ext(basename(f))) })
  print('Processing global country data')
  lapply(allFiles, FUN = function(f) { processGlobalCovidData(read.csv(f), file_path_sans_ext(basename(f))) })
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
