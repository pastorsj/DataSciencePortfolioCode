# Global Covid Cases 
library(dplyr)
library(tools)

basePath = 'raw_data'
processedDataPath = 'processed_data/'
start <- as.Date("01-22-2020",format="%m-%d-%y")
todaysDate <- as.Date(Sys.Date(),format="%m-%d-%y")
base_url <- 'https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_daily_reports/'

getAllData <- FALSE
processAllData <- TRUE

processRow <- function (row) {
  country <- row[1]
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
  print('Processing file with date')
  print(formattedDate)
  
  colnames(df)[which(names(df) == 'Country/Region')] <- 'Country.Region'
  colnames(df)[which(names(df) == 'Country_Region')] <- 'Country.Region'
  
  groupedByCountry <- df %>% 
    filter(!is.na(Confirmed)) %>%
    group_by(Country = Country.Region) %>%
    summarize(Confirmed = sum(Confirmed, na.rm = TRUE), Date = formattedDate) %>% 
    mutate(Confirmed = as.numeric(Confirmed),
           Country = as.character(Country),
           Date = as.Date(Date,format="%m-%d-%y")
    )
  
    apply(groupedByCountry, 1, processRow)
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
