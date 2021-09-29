# ------------------Libraries------------------
library(dplyr)
library(tools)
library(tidyverse)
library(gsubfn)
library(AnomalyDetection)
library(hrbrthemes)
library(timetk)
library(aws.s3)
# ---------------------------------------------

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

basePath <- 'raw_data'
processedDataPath <- 'processed_data'
processedDataVisualizations = 'processed_data_visualizations'

createDirectoryIfNotExists(basePath)
createDirectoryIfNotExists(paste(processedDataPath, 'global', sep = '/'))
createDirectoryIfNotExists(paste(processedDataPath, 'state', sep = '/'))
createDirectoryIfNotExists(processedDataVisualizations)

# Defined Constants 
start <- as.Date("01-22-2020",format="%m-%d-%y")
todaysDate <- as.Date(Sys.Date(),format="%m-%d-%y")
base_url <- 'https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_daily_reports/'
statesPlusDC <- c(state.name, 'District of Columbia')
stateAbbrPlusDC <- c(state.abb, 'DC')

# -------------------- Control Panel --------------------
getAllData <- FALSE

visualizeRawData <- FALSE

processAllData <- FALSE
processUsData <- FALSE
processGlobalData <- TRUE

visualizeProcessedData <- FALSE
visualizeUsProcessedData <- FALSE
visualizeGlobalProcessedData <- TRUE

uploadDataToS3 <- FALSE
uploadRawDataToS3 <- FALSE
uploadProcessedDataToS3 <- FALSE
uploadVisualizationsToS3 <- TRUE

# -------------------------------------------------------

#' Processes a row in the dataframe grouped by either country or state.
#' This code reads in the row and adds it to the appropriate file if it exists
#' already or creates a new csv
#' 
#' @param row A row of data
#' @param type The type of data (typically either 'global' or 'states')
processRow <- function (row, type) {
  country <- row[1]
  date <- row[3]
  fileName <- paste(processedDataPath, type, paste(country, '.csv', sep = ''), sep = '/')
  # if there is a csv file that exists with the country.region name, open it into a dataframe, else create a new one
  if (file.exists(fileName)) {
    csv <- read.csv(fileName)
    nextConfirmed <- as.numeric(row['Confirmed'])
    lastConfirmed <- tail(csv$Confirmed, n = 1)
    row['Cases'] <- nextConfirmed - lastConfirmed
    df <- rbind(csv, t(row))
    write.csv(df, fileName, row.names = FALSE)
  } else {
    row['Cases'] <- as.numeric(row['Confirmed'])
    
    df <- data.frame(t(row), row.names = NULL)
    write.csv(df, file = fileName, row.names = FALSE)
  }
}

#' Processes a dataframe associated with a date. This dataframe contains
#' daily information on covid cases per country/region.
#' 
#' @param df A dataframe
#' @param formattedDate The date of the information
processGlobalCovidData <- function(df, formattedDate) {
  # Preprocess and save again into another R data source, this time by country
  # for each country in the df
  
  # Some of the column names were inconsistent
  colnames(df)[which(names(df) == 'Country/Region')] <- 'Country.Region'
  colnames(df)[which(names(df) == 'Country_Region')] <- 'Country.Region'
  
  groupedByCountry <- df %>% 
    filter(!is.na(Confirmed)) %>%
    group_by(Country = Country.Region) %>%
    summarize(Confirmed = sum(Confirmed, na.rm = TRUE), Date = formattedDate)
  
  apply(groupedByCountry, 1, FUN = function(row) processRow(row, 'global'))
  
  print('Processed global covid data for date')
  print(formattedDate)
}

#' Cleans a list of states associated with Covid data
#' 
#' @param sts A list of states, typically abbreviations
#' @return The list of cleaned states with full names rather than abbreviations
cleanStates <- function(sts) {
  resultingStates <- character()
  for (s in sts) {  
    if(grepl(', ', s)) {
      # Early on, the covid data including locations of origin of people when they contracted covid on a cruise 
      # ship called the Diamond Princess
      cleanedState <- str_replace(s, fixed('(From Diamond Princess)'), '')
      # Clean up the DC abbreviation
      cleanedState <- str_replace(cleanedState, fixed('D.C.'), 'DC')
      # Some states were abbreviated, some were not.
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

#' Processes a dataframe associated with a date. This dataframe contains
#' daily information on covid cases per country/region. Rather than process 
#' every country, we only need to process the United States, but grouped 
#' together by state.
#' 
#' @param df A dataframe
#' @param formattedDate The date of the information
processUSCovidData <- function(df, formattedDate) {
  # Preprocess and save again into another R datasource, this time by country
  # for each country in the df
  print('Grouping by state')
  print(formattedDate)
  
  # Some of the column names were inconsistent
  colnames(df)[which(names(df) == 'Country/Region')] <- 'Country.Region'
  colnames(df)[which(names(df) == 'Country_Region')] <- 'Country.Region'
  colnames(df)[which(names(df) == 'Province/State')] <- 'Province.State'
  colnames(df)[which(names(df) == 'Province_State')] <- 'Province.State'
  
  # Filter all countries out besides the US, group by state, and summarize
  groupedByState <- df %>% 
    filter(!is.na(Confirmed)) %>%
    filter(Country.Region == 'US') %>%
    mutate(Province.State = cleanStates(Province.State)) %>%
    group_by(State = Province.State) %>%
    filter(Province.State %in% statesPlusDC) %>%
    summarize(Confirmed = sum(Confirmed, na.rm = TRUE), Date = formattedDate)
  
  apply(groupedByState, 1, FUN = function(row) processRow(row, 'state'))

  print('Processed us state covid data for date')
  print(formattedDate)
}

#' Visualizes processed state data using a package that also plots 
#' anomalies. This is helpful when exploring the data.
#' 
#' @param file A file containing a dataframe with state data
visualizeProcessedStateData <- function(file) {
  df <- read.csv(file)
  print('Creating a visualization for the following state')
  extractedState <- df$State[1]
  print(extractedState)

  # Make doubly sure the data types are correct
  df$Date <- as.Date(df$Date, '%m-%d-%Y')
  df$Cases <- as.numeric(df$Cases)

  p <- plot_anomaly_diagnostics(
    .data=df, 
    .date_var = Date, 
    .value = Cases,
    .message = FALSE,
    .facet_ncol = 3,
    .ribbon_alpha = 0.25,
    .title = paste("Covid Cases (per day) in ", extractedState, sep = ''),
    .x_lab = "Date",
    .y_lab = "Cases",
    .interactive = TRUE)
  
  print('Saving plot of data')
  htmlwidgets::saveWidget(as_widget(p), paste(processedDataVisualizations, 'state', paste(extractedState, '.html', sep = ''), sep = '/'))
}

#' Visualizes processed global data using a package that also plots 
#' anomalies. This is helpful when exploring the data.
#' 
#' @param file A file containing a dataframe with country data
visualizeProcessedGlobalData <- function(file) {
  df <- read.csv(file)
  extractedCountry <- df$Country[1]
  # In some cases, the countries have data, but a very small amount (less than
  # 10 recorded cases). In this case, the plotting software crashes, so a try 
  # catch is needed. In the case it fails, no plot will be created.
  tryCatch({
    print('Creating a visualization for the following country')
    print(extractedCountry)
    
    # Make doubly sure the data types are correct
    df$Date <- as.Date(df$Date, '%m-%d-%Y')
    df$Cases <- as.numeric(df$Cases)
    
    p <- plot_anomaly_diagnostics(
      .data=df, 
      .date_var = Date, 
      .value = Cases,
      .message = FALSE,
      .facet_ncol = 3,
      .ribbon_alpha = 0.25,
      .title = paste("Covid Cases (per day) in ", extractedCountry, sep = ''),
      .x_lab = "Date",
      .y_lab = "Cases",
      .interactive = TRUE)
    
    print('Saving plot of data')
    htmlwidgets::saveWidget(as_widget(p), paste(processedDataVisualizations, 'global', paste(extractedCountry, '.html', sep = ''), sep = '/'))
  }, error = function(cond) {
    print('^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^')
    print('Unable to create visualization')
    print(extractedCountry)
    print(cond)
    print('^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^')
  })
}

#' Determines the raw s3 file path used when uploading the data to S3
#' 
#' @param file An existing file path
#' @param directory A directory to categorize the data in S3
#' @returns The s3 file path
#' @examples 
#' determineRawS3FilePath('raw_data/data.csv', 'specific_path_in_s3') => 'raw_data/specific_path_in_s3/data.csv'
determineRawS3FilePath <- function(file, directory) {
  folderStructure <- unlist(strsplit(file, split = '/'))
  s3FilePath <- paste(folderStructure[1], directory, folderStructure[2], sep = '/')
  return(s3FilePath)
}

#' Stores a file in S3
#' 
#' @param file A file
#' @param directory The final location for the file in S3
storeDataInS3 <- function(file, s3FilePath) {
  print('Storing file in s3')
  print(s3FilePath)
  put_object(file = file, object = s3FilePath, bucket = 'datastore.portfolio.sampastoriza.com')
  print('Uploaded file to S3 successfully')
}

# -------------------------- Control Panel Processor -------------------------- 
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
  allFiles = list.files(basePath, full.names = TRUE)
  # Order files by date
  filesOrderedByDate <- allFiles[order(as.Date(strapplyc(allFiles, "\\d{2}-\\d+{2}-\\d{4}", simplify = TRUE), format =  "%m-%d-%Y"))]
  if (processUsData) {
    unlink("processed_data/state/*")
    print('Processing state data')
    lapply(filesOrderedByDate, FUN = function(f) { processUSCovidData(read.csv(f), file_path_sans_ext(basename(f))) })
  }
  if (processGlobalData) {
    unlink("processed_data/global/*")
    print('Processing global data')
    lapply(filesOrderedByDate, FUN = function(f) { processGlobalCovidData(read.csv(f), file_path_sans_ext(basename(f))) })
  }
}
if (visualizeProcessedData) {
  if (visualizeUsProcessedData) {
    print('Visualizing processed US data')
    allFiles = list.files(paste(processedDataPath, 'state', sep = '/'), full.names = TRUE)
    lapply(allFiles, FUN = function(f) visualizeProcessedStateData(f))
  }
  if (visualizeGlobalProcessedData) {
    print('Visualizing processed global data')
    allFiles = list.files(paste(processedDataPath, 'global', sep = '/'), full.names = TRUE)
    lapply(allFiles, FUN = function(f) visualizeProcessedGlobalData(f))
  }  
}
if (uploadDataToS3) {
  if (uploadRawDataToS3) { 
    print('Uploading raw covid cases data to S3')
    allFiles <- list.files(basePath, full.names = TRUE, pattern = '*.csv')
    lapply(allFiles, FUN = function(f) { storeDataInS3(f, determineRawS3FilePath(f, 'covid_cases')) })
  }
  if (uploadProcessedDataToS3) {
    print('Uploading processed covid cases data to S3')
    allFiles <- list.files(processedDataPath, full.names = TRUE, pattern = '*.csv', recursive = TRUE)
    lapply(allFiles, FUN = function(f) { storeDataInS3(f, f) })
  }
  if (uploadVisualizationsToS3) {
    print('Uploading processed covid cases data visualizations to S3')
    allFiles <- list.files(processedDataVisualizations, full.names = TRUE, pattern = '*.html$', recursive = TRUE)
    lapply(allFiles, FUN = function(f) { storeDataInS3(f, f) })
  }
}
# ------------------------------------------------------------------------------
