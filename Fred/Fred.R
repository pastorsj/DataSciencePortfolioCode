# ------------------Libraries------------------
library(tidyverse)
library(plotly)
library(fredr)
library(tools)
library(randomcoloR)
library(AnomalyDetection)
library(hrbrthemes)
library(aws.s3)
# ---------------------------------------------

# Uncomment once to set the fred api key.
# See https://cran.r-project.org/web/packages/fredr/vignettes/fredr.html
# usethis::edit_r_environ()

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

dataFolder <- 'raw_data'
processedDataPath <- 'processed_data'
processedDataVisualizations = 'processed_data_visualizations'

createDirectoryIfNotExists(dataFolder)
createDirectoryIfNotExists(processedDataPath)
createDirectoryIfNotExists(processedDataVisualizations)

# Defined Constants 
foodAndHospitalitySuffix <- '-employment-food-and-hospitality'
foodManufacturingSuffix <- '-employment-food-manufacturing'
foodAndHospitalityRds <- function(state) paste(state, foodAndHospitalitySuffix, '.rds', sep = '')
foodAndHospitalityCsv <- function(state) paste(state, foodAndHospitalitySuffix, '.csv', sep = '')
foodManufacturingRds <- function(state) paste(state, foodManufacturingSuffix, '.rds', sep = '')
foodManufacturingCsv <- function(state) paste(state, foodManufacturingSuffix, '.csv', sep = '')

# -------------------- Control Panel --------------------

retrieveRawData <- FALSE
retrieveLAHRawData <- TRUE
retrieveMRawData <- TRUE

processRawData <- FALSE
processLAHRawData <- TRUE
processMRawData <- TRUE

visualizeProcessedData <- FALSE
visualizeLAHProcessedData <- TRUE
visualizeMProcessedData <- TRUE

uploadDataToS3 <- FALSE
uploadRawDataToS3 <- TRUE
uploadProcessedDataToS3 <- TRUE
uploadVisualizationsToS3 <- TRUE

# -------------------------------------------------------

#' Retrieves the raw leisure and hospitality employment data for 50 states
retrieveLeisureAndHospitalityEmploymentDataFor50States <- function() {
  seriesIds <- c(1:56)
  for (i in seriesIds) { 
    # Create the FRED series id associated with leisure and hospitality employment data
    seriesId <- paste('SMU', str_pad(i, 2, pad = '0'), '000007072200001SA', sep = '')
    print('Retrieving hospitality and leisure series with id')
    print(seriesId)
    # Attempt to retrieve data for each state. In some cases, the state may not have data,
    # in which case, the FRED api will fail. In the case it fails, we print a message 
    # and move on.
    tryCatch({
      # Using a library, we make the request against the FRED api
      seriesInformation <- fredr_request(series_id = seriesId, endpoint = "series")
      extractedState <- str_extract(seriesInformation$title, paste(state.name, collapse='|'))
      observations <- fredr(series_id = seriesId)
      df <- data.frame(Date = observations$date, Value = observations$value)
      # Add some extra information to the raw data for context
      df$Units <- seriesInformation$units
      df$State = extractedState
      df$Frequency = seriesInformation$frequency
      df$Notes = seriesInformation$notes
      df$LastUpdated = seriesInformation$last_updated
      
      print('Saving raw data to file')
      print(foodAndHospitalityCsv(extractedState))
      # Save to RDS for faster access later
      saveRDS(df, paste(dataFolder, foodAndHospitalityRds(extractedState), sep = '/'))
      
      # Save to CSV for viewing purposes
      write.csv(df, paste(dataFolder, foodAndHospitalityCsv(extractedState), sep = '/'), row.names = FALSE)
    }, error = function(cond) {
      print('********************************************')
      print('No series information exists for this id')
      print('********************************************')
    })
  }
}

#' Retrieves the raw leisure and hospitality employment data for 50 states
retrieveManufacturingEmploymentDataFor50States <- function() {
  seriesIds <- c(1:56)
  for (i in seriesIds) { 
    # Create the FRED series id associated with food manufacturing employment data
    seriesId <- paste('SMU', str_pad(i, 2, pad = '0'), '000003231100001SA', sep = '')
    print('Retrieving food manufacturing series with id')
    print(seriesId)
    # Attempt to retrieve data for each state. In some cases, the state may not have data,
    # in which case, the FRED api will fail. In the case it fails, we print a message 
    # and move on.
    tryCatch({
      seriesInformation <- fredr_request(series_id = seriesId, endpoint = "series")
      print(seriesInformation$title)
      extractedState <- str_extract(seriesInformation$title, paste(state.name, collapse='|'))
      observations <- fredr(series_id = seriesId)
      df <- data.frame(Date = observations$date, Value = observations$value)
      # Add some extra information to the raw data for context
      df$Units <- seriesInformation$units
      df$State = extractedState
      df$Frequency = seriesInformation$frequency
      df$Notes = seriesInformation$notes
      df$LastUpdated = seriesInformation$last_updated
      
      print('Saving raw data to file')
      print(foodManufacturingCsv(extractedState))
      # Save to RDS for faster access later
      saveRDS(df, paste(dataFolder, foodManufacturingRds(extractedState), sep = '/'))
      
      # Save to CSV for viewing purposes
      write.csv(df, paste(dataFolder, foodManufacturingCsv(extractedState), sep = '/'), row.names = FALSE)
    }, error = function(cond) {
      print('********************************************')
      print('No series information exists for this id')
      print('********************************************')
    })
  }
}

#' Processes food and hospitality data per state, runs anomaly detection, and 
#' writes the processed data to a csv
#' 
#' @param df The input dataframe
processFoodAndHospitalityDataForState <- function(df) {
  state = df$State[1]
  print(paste('Exploring the food and hospitality data for ', state, sep=''))
  cleanedDf <- data.frame(timestamp = as.Date(df$Date), count = as.numeric(df$Value))
  print(head(cleanedDf))
  # Use the AnomalyDetection library from Twitter to detect anomalies in time series data
  res = AnomalyDetectionTs(cleanedDf, max_anoms = 0.02, direction = 'pos', plot = TRUE)
  if (nrow(res$anoms) == 0) {
    print('No anomalies detected in the time series data')
  } else {
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
    print('An anomaly was detected')
    print(head(res$anoms))
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
  }
  
  print('Writing cleaned data to processed folder')
  write.csv(cleanedDf, paste(processedDataPath, foodAndHospitalityCsv(state), sep = '/'), row.names = FALSE)
}

#' Processes food manufacturing data per state, runs anomaly detection, and 
#' writes the processed data to a csv
#' 
#' @param df The input dataframe
processFoodManufacturingDataForState <- function(df) {
  state = df$State[1]
  print(paste('Exploring the food manufacturing data for ', state, sep=''))
  cleanedDf <- data.frame(timestamp = as.Date(df$Date), count = as.numeric(df$Value))
  print(head(cleanedDf))
  # Use the AnomalyDetection library from Twitter to detect anomalies in time series data
  res = AnomalyDetectionTs(cleanedDf, max_anoms = 0.02, direction = 'pos')
  if (nrow(res$anoms) == 0) {
    print('No anomalies detected in the time series data')
  } else {
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
    print('An anomaly was detected')
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
    print(head(res$anoms))
  }
  
  print('Writing cleaned data to processed folder')
  write.csv(cleanedDf, paste(processedDataPath, foodManufacturingCsv(state), sep = '/'), row.names = FALSE)
}

#' Visualizes the food and hospitality data per state using ggplot and plotly
#' 
#' @param df The input dataframe
#' @param filename The filename containing the state
visualizeFoodAndHospitalityDataForState <- function(df, filename) {
  state <- sub(foodAndHospitalitySuffix, '', filename)
  print('Creating a plot of the cleaned food and hospitality data for')
  print(state)
  df$timestamp <- as.Date(df$timestamp)
  plotColor <- randomColor()
  p <- df %>%
    ggplot(aes(x=timestamp, y=count)) +
    geom_area(fill=plotColor, alpha=0.5) +
    geom_line(color=plotColor) +
    labs(x = "Date", y = "Employed (Thousands of Persons)", 
         title = paste("Food and Hospitality Employment for ", state, sep = '')) +
    theme_ipsum()
  p <- ggplotly(p)
  print('Saving plot of data')
  htmlwidgets::saveWidget(as_widget(p), paste(processedDataVisualizations, paste(state, '-employment-food-and-hospitality.html', sep = ''), sep = '/'))
}

#' Visualizes the food manufacturing employment data per state using ggplot and plotly
#' 
#' @param df The input dataframe
#' @param filename The filename containing the state
visualizeFoodManufacturingForState <- function(df, filename) {
  state <- sub(foodManufacturingSuffix, '', filename)
  print('Creating a plot of the cleaned food manufacturing data for ')
  print(state)
  df$timestamp <- as.Date(df$timestamp)
  plotColor <- randomColor()
  p <- df %>%
    ggplot(aes(x=timestamp, y=count)) +
    geom_area(fill=plotColor, alpha=0.5) +
    geom_line(color=plotColor) +
    labs(x = "Date", y = "Employed (Thousands of Persons)", 
         title = paste("Food Manufacturing Employment for ", state, sep = '')) +
    theme_ipsum()
  p <- ggplotly(p)
  print('Saving plot of data')
  htmlwidgets::saveWidget(as_widget(p), paste(processedDataVisualizations, paste(state, '-employment-food-manufacturing.html', sep = ''), sep = '/'))
}

#' Stores a file in S3
#' 
#' @param file A file
#' @param suffix The type of data. Used to strip from the filename for cleaning purposes
#' @param directory The inner directory used to store the data in S3
storeDataInS3 <- function(file, suffix, directory) {
  folderStructure <- unlist(strsplit(file, split = '/'))
  s3FilePath <- paste(folderStructure[1], directory, sub(suffix, '', folderStructure[2]), sep = '/')
  print('Storing file in s3')
  print(s3FilePath)
  put_object(file = file, object = s3FilePath, bucket = 'datastore.portfolio.sampastoriza.com')
  print('Uploaded file to S3 successfully')
}

# -------------------------- Control Panel Processor -------------------------- 

if (retrieveRawData) {
  if (retrieveLAHRawData) {
    unlink(paste('raw_data/*', foodAndHospitalitySuffix, '.*', sep = ''))
    retrieveLeisureAndHospitalityEmploymentDataFor50States()
    
    allFiles <- list.files(dataFolder, pattern = '*-employment-food-and-hospitality.csv')
    allExtractedStates <- sub('-employment-food-and-hospitality.csv', '', allFiles)
    missingStates <- state.name[!state.name %in% allExtractedStates]
    print('FRED API is missing the following states\' leisure and hospitality employment data')
    print(missingStates)
  }
  if (retrieveMRawData) {
    unlink(paste('raw_data/*', foodManufacturingSuffix, '.*', sep = ''))
    retrieveManufacturingEmploymentDataFor50States()
    
    allFiles <- list.files(dataFolder, pattern = '*-employment-food-manufacturing.csv')
    allExtractedStates <- sub('-employment-food-manufacturing.csv', '', allFiles)
    missingStates <- state.name[!state.name %in% allExtractedStates]
    print('FRED API is missing the following states\' food manufacturing employment data')
    print(missingStates)
  }
}
if (processRawData) {
  print('Processing raw data')
  if (processLAHRawData) {
    unlink(paste('processed_data/*', foodAndHospitalitySuffix, '.*', sep = ''))
    allFiles <- list.files(dataFolder, full.names = TRUE, pattern = '*-employment-food-and-hospitality.rds')
    lapply(allFiles, FUN = function(f) { processFoodAndHospitalityDataForState(readRDS(f)) })
  }
  if (processMRawData) {
    unlink(paste('processed_data/*', foodManufacturingSuffix, '.*', sep = ''))
    allFiles <- list.files(dataFolder, full.names = TRUE, pattern = '*-employment-food-manufacturing.rds')
    print('All files')
    print(allFiles)
    lapply(allFiles, FUN = function(f) { processFoodManufacturingDataForState(readRDS(f)) })
  }
}
if (visualizeProcessedData) {
  print('Visualizing processed data')
  if (visualizeLAHProcessedData) {
    allFiles <- list.files(processedDataPath, full.names = TRUE, pattern = '*-employment-food-and-hospitality.csv')
    lapply(allFiles, FUN = function(f) { visualizeFoodAndHospitalityDataForState(read.csv(f), file_path_sans_ext(basename(f))) })
  }
  if (visualizeMProcessedData) {
    allFiles <- list.files(processedDataPath, full.names = TRUE, pattern = '*-employment-food-manufacturing.csv')
    lapply(allFiles, FUN = function(f) { visualizeFoodManufacturingForState(read.csv(f), file_path_sans_ext(basename(f))) })
  }
}
if (uploadDataToS3) {
  if (uploadRawDataToS3) {
    print('Uploading raw food and hospitality data to S3')
    allFiles <- list.files(dataFolder, full.names = TRUE, pattern = '*-employment-food-and-hospitality.csv')
    lapply(allFiles, FUN = function(f) { storeDataInS3(f, foodAndHospitalitySuffix, 'food_and_hospitality_employment') })
    print('Uploading raw food manufacturing data to S3')
    allFiles <- list.files(dataFolder, full.names = TRUE, pattern = '*-employment-food-manufacturing.csv')
    lapply(allFiles, FUN = function(f) { storeDataInS3(f, foodManufacturingSuffix, 'food_manufacturing_employment') })
  }
  if (uploadProcessedDataToS3) {
    print('Uploading processed food and hospitality data to S3')
    allFiles <- list.files(processedDataPath, full.names = TRUE, pattern = '*-employment-food-and-hospitality.csv')
    lapply(allFiles, FUN = function(f) { storeDataInS3(f, foodAndHospitalitySuffix, 'food_and_hospitality_employment') })
    print('Uploading processed food manufacturing data to S3')
    allFiles <- list.files(processedDataPath, full.names = TRUE, pattern = '*-employment-food-manufacturing.csv')
    lapply(allFiles, FUN = function(f) { storeDataInS3(f, foodManufacturingSuffix, 'food_manufacturing_employment') })
  }
  if (uploadVisualizationsToS3) {
    print('Uploading visualizations for food and hospitality data to S3')
    allFiles <- list.files(processedDataVisualizations, full.names = TRUE, pattern = '*-employment-food-and-hospitality.html')
    lapply(allFiles, FUN = function(f) { storeDataInS3(f, foodAndHospitalitySuffix, 'food_and_hospitality_employment') })
    print('Uploading visualizations for food manufacturing data to S3')
    allFiles <- list.files(processedDataVisualizations, full.names = TRUE, pattern = '*-employment-food-manufacturing.html')
    lapply(allFiles, FUN = function(f) { storeDataInS3(f, foodManufacturingSuffix, 'food_manufacturing_employment') })
  }
}

# ------------------------------------------------------------------------------
