# ------------------Libraries------------------
library('FAOSTAT')
library(tidyverse)
library(plotly)
library(purrr)
library(maps)
library(dygraphs)
library(xts)
library(lubridate)
library(randomcoloR)
library(tools)
library('aws.s3')
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

dataFolder <- 'raw_data'
processedDataPath <- 'processed_data'
rawDataVisualizations = 'raw_data_visualizations'
processedDataVisualizations = 'processed_data_visualizations'

createDirectoryIfNotExists(dataFolder)
createDirectoryIfNotExists(processedDataPath)
createDirectoryIfNotExists(rawDataVisualizations)
createDirectoryIfNotExists(processedDataVisualizations)
createDirectoryIfNotExists(paste(processedDataVisualizations, 'consumer_price_indices', 'general_indices', sep = '/'))
createDirectoryIfNotExists(paste(processedDataVisualizations, 'consumer_price_indices', 'food_indices', sep = '/'))
createDirectoryIfNotExists(paste(processedDataVisualizations, 'consumer_price_indices', 'food_price_inflation', sep = '/'))
createDirectoryIfNotExists(paste(processedDataVisualizations, 'food_security_indicators', 'food_supply_variability', sep = '/'))
createDirectoryIfNotExists(paste(processedDataVisualizations, 'food_security_indicators', 'food_insecurity_population_percent', sep = '/'))

# Defined Constants 
currentYearMinus1 <- as.integer(format(Sys.Date(), "%Y")) - 1
startingYear <- 2000
naValue <- 9999999

# -------------------- Control Panel --------------------

retrieveRawData <- FALSE

visualizeRawData <- FALSE
visualizeRawConsumerPriceData <- TRUE
visualizeRawFoodSecurityIndicatorData <- TRUE

processRawData <- FALSE
processFoodIndicatorData <- TRUE
processConsumerPriceData <- TRUE

visualizeProcessedData <- FALSE
visualizeConsumerPriceIndexData <- TRUE
visualizeFoodSecurityIndicatorData <- TRUE

uploadDataToS3 <- TRUE
uploadRawDataToS3 <- TRUE
uploadRawVisualizationsToS3 <- TRUE
uploadProcessedDataToS3 <- TRUE
uploadProcessedVisualizationsToS3 <- TRUE

# -------------------------------------------------------

#' Downloads and stores raw data from the FAO api and stores it in bulk
#' 
#' @param bulkDataFile The name of the bulk data file
#' @param rdsFileName The name of the output file
downloadAndStoreDataFromFAO = function(bulkDataFile, rdsFileName) {
  # The bulk url for the FAO api
  urlBulkUrl <- "http://fenixservices.fao.org/faostat/static/bulkdownloads"
  bulkData <- file.path(urlBulkUrl, paste(bulkDataFile, '.zip', sep = '' ))
  # Download the FAO Stat data in bulk and store it
  download_faostat_bulk(url_bulk = bulkData, data_folder = dataFolder)
  
  # Read the faostat data in bulk
  bulkData <- read_faostat_bulk(paste(dataFolder, paste(bulkDataFile, '.zip', sep = ''), sep = '/'))
  print(head(bulkData))
  
  # Save to RDS for faster access later
  saveRDS(bulkData, paste(dataFolder, paste(rdsFileName, '.rds', sep = ''), sep = '/'))
  
  # Save to CSV for viewing purposes
  write.csv(bulkData, paste(dataFolder, paste(rdsFileName, '.csv', sep = ''), sep = '/'))
}

#' Processes an indicator code and creates a dataframe as output
#' 
#' @param df The input dataframe
#' @returns A cleaned dataframe contains information on the indicator, the unit of measure, the year, and the value of the indicator
processIndicatorCode <- function(df) {
  newDataframe <- data.frame(IndicatorCode = integer(), Description = character(), UnitOfMeasure = character(), Year = integer(), Value = numeric())
  yearColNames <- colnames(df)
  # Extract columns that either look like 'y2000' or 'y20002002' for 3 year averages
  yearColNames <- yearColNames[grepl('y[0-9]{4,8}$', yearColNames)]
  if (grepl('(3-year average)', df$item, fixed = TRUE)) {
    # Find column names that indicate a 3 year average is taken
    yearColNames <- yearColNames[grepl('y[0-9]{8}$', yearColNames)]
    for (year in yearColNames) {
      extractedYears <- sub('y', '', year)
      boundingYears <- as.integer(strsplit(extractedYears, "(?<=.{4})", perl = TRUE)[[1]])
      years <- sort(c(boundingYears, boundingYears[1] + 1))
      value <- ifelse(is.na(df[year]) | df[year] == '', naValue, df[year])
      # Sometimes the value is set to <0.1. In that case, the value is set to 0
      if (value[[1]] == '<0.1') {
        value[[1]] <- 0
      }
      for (extractedYear in years) {
        newDataframe[nrow(newDataframe) + 1, ] = c(df$item_code, df$item, df$unit, extractedYear, as.numeric(value))
      }
    }
    newDataframe$Value = as.numeric(newDataframe$Value)
    # Group by year and take the mean
    newDataframe <- newDataframe %>%
      filter(Value != naValue) %>%
      group_by(Year = Year) %>%
      summarize(Value = mean(Value))
    
    if (nrow(newDataframe) == 0) {
      print('**************************')
      print('All values for a particular area are empty.')
      print(df$area[[1]])
      print(df$item[[1]])
      print('**************************')
      return(newDataframe)
    } else {
      newDataframe = as.data.frame(newDataframe)
      newDataframe$IndicatorCode = df$item_code
      newDataframe$Description = df$item
      newDataframe$UnitOfMeasure = df$unit
    }
  } else {
    # Find column names that indicate a yearly average is taken
    yearColNames <- yearColNames[grepl('y[0-9]{4}$', yearColNames)]
    for (year in yearColNames) {
      extractedYear <- sub('y', '', year)
      value <- ifelse(is.na(df[year]) | df[year] == '', naValue, df[year])
      if (value[[1]] == '<0.1') {
        value[[1]] <- 0
      }
      
      if (value != naValue) {
        newDataframe[nrow(newDataframe) + 1, ] = c(df$item_code, df$item, df$unit, extractedYear, as.numeric(value))
      }
    }
  }
  return(newDataframe)
}

#' Processes the raw FAO Stat food security indicator data by country and 
#' writes the results to a set of csv files
#' 
#' @param df The raw dataframe containing food security indicator information
processCountry <- function(df) {
  # Clean up countries with special characters. CSV names do not like special characters
  country <- iconv(df$area[1], from = 'UTF-8', to = 'ASCII//TRANSLIT')
  # Standardize the United States country name
  if (!is.na(country) & country == 'United States of America') {
    country = 'United States'
  }
  if (!is.na(country) & country == 'Viet Nam') {
    country = 'Vietnam'
  }
  if (is.na(country) | !(country %in% iso3166$ISOname)) {
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
    print('Unable to process country with name')
    print(df$area[1])
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
  } else {
    newDataframe <- data.frame(IndicatorCode = integer(), Description = character(), UnitOfMeasure = character(), Year = integer(), Value = double())
    groupedByIndicatorCode <- split(df, df$item_code)
    # print(processIndicatorCode(groupedByIndicatorCode$"21016"))
    newDFs <- lapply(groupedByIndicatorCode, processIndicatorCode)
    for (df1 in newDFs) {
      if (nrow(df1) != 0) {
        newDataframe <- rbind(newDataframe, df1)
      }
    }
    fileName = paste(processedDataPath, paste(country, '-food-security-indicators.csv', sep = ''), sep = '/')
    print('Writing processed FAO Food Security Indicator Data to file')
    print(fileName)
    write.csv(newDataframe, fileName, row.names = FALSE)
  }
}

#' Converts a month and year into a date
#' 
#' @param year The year
#' @param rawMonth The month
#' @returns The date given the month and year
#' @examples 
#' extractDateGivenMonthAndYear(2020, 'January') => 01-01-2020
extractDateGivenMonthAndYear <- function(year, rawMonth) {
  # Use the internal R variable month to extract the numeric value of the rawMonth parameter
  convertedMonth <- str_pad(match(rawMonth, month.name), 2, pad = '0')
  extractedDate <- paste(convertedMonth, '01', year, sep = '-')
  return(extractedDate)
}

#' Processes a consumer price index by country
#' 
#' @param df The raw dataframe containing consumer price indices information
processPriceIndex <- function(df) {
  newDataframe <- data.frame(IndicatorCode = integer(), Description = character(), UnitOfMeasure = character(), Date = character(), Value = numeric())
  yearColNames <- colnames(df)
  yearColNames <- yearColNames[grepl('y[0-9]{4}$', yearColNames)]
  groupedByMonth = split(df, df$months)
  for (year in yearColNames) {
    extractedYear <- sub('y', '', year)
    for (row in groupedByMonth) {
      value <- ifelse(is.na(row[year]) | row[year] == '', naValue, row[year])
      extractedDate <- extractDateGivenMonthAndYear(extractedYear, row$months)
      newDataframe[nrow(newDataframe) + 1, ] = c(row$item_code, row$item, row$unit, extractedDate, as.numeric(value))
    }
  }
  newDataframe <- newDataframe[order(as.Date(newDataframe$Date, format = "%m-%d-%Y")),]
  newDataframe <- newDataframe[newDataframe$Value != naValue, ]
  return(newDataframe)
}

#' Processes the raw FAO Stat consumer price index data by country and 
#' writes the results to a set of csv files
#' 
#' @param df The raw dataframe containing consumer price indices information
processIndicesByCountry <- function(df) {
  country <- iconv(df$area[1], from = 'UTF-8', to = 'ASCII//TRANSLIT')
  if (!is.na(country) & country == 'United States of America') {
    country = 'United States'
  }
  if (!is.na(country) & country == 'Viet Nam') {
    country = 'Vietnam'
  }
  if (is.na(country) | !(country %in% iso3166$ISOname)) {
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
    print('Unable to process country with name')
    print(df$area[1])
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
  } else {
    newDataframe <- data.frame(IndicatorCode = integer(), Description = character(), UnitOfMeasure = character(), Date = integer(), Value = double())
    groupedByIndicatorCode <- split(df, df$item_code)
    newDFs <- lapply(groupedByIndicatorCode, processPriceIndex)
    for (df1 in newDFs) {
      newDataframe <- rbind(newDataframe, df1)
    }
    fileName = paste(processedDataPath, paste(country, '-consumer-price-indices.csv', sep = ''), sep = '/')
    print('Writing processed FAO Consumer Price Indices to file')
    print(fileName)
    write.csv(newDataframe, fileName, row.names = FALSE)
  }
}

#' Processes the food security indicators by country
#' 
#' @param df The raw dataframe containing food security indicator information
processFoodSecurityIndicatorData <- function(df) {
  groupedByCountry <- split(df, df$area)
  lapply(groupedByCountry, processCountry)
}

#' Processes the consumer price indices  by country
#' 
#' @param df The raw dataframe containing consumer price indices information
processConsumerPriceIndicesData <- function(df) {
  groupedByCountry <- split(df, df$area)
  lapply(groupedByCountry, processIndicesByCountry)
}

#' Visualizes the raw consumer price index information by country
#' 
#' @param itemCode The item code associated with an index
#' @param month The month being visualized
#' @param year The year being visualized
visualizeRawGlobalConsumerPriceData <- function(itemCode, month, year) {
  print('Visualizing raw global consumer price data')
  yearColumn = paste('y', year, sep = '')
  consumerPriceIndices <- paste(dataFolder, paste('consumer_price_indices', '.rds', sep = ''), sep = '/')
  consumerPriceIndicesDF <- readRDS(consumerPriceIndices)
  consumerPriceIndicesDF <- consumerPriceIndicesDF[
    (consumerPriceIndicesDF$item_code == itemCode) &
      (consumerPriceIndicesDF$months == month) &
      (!is.na(consumerPriceIndicesDF[yearColumn])), ]
  
  consumerPriceIndicesDF$area <- iconv(consumerPriceIndicesDF$area, from = 'UTF-8', to = 'ASCII//TRANSLIT')
  consumerPriceIndicesDF <- subset(consumerPriceIndicesDF, select = c('area', yearColumn))
  consumerPriceIndicesDF$area[consumerPriceIndicesDF$area == 'United States of America'] <- 'United States'
  consumerPriceIndicesDF$area[consumerPriceIndicesDF$area == 'Viet Nam'] <- 'Vietnam'
  # Remove countries that have names that can't be converted to ASCII encoding.
  consumerPriceIndicesDF <- consumerPriceIndicesDF[
    (!is.na(consumerPriceIndicesDF$area)) & 
      (consumerPriceIndicesDF$area %in% iso3166$ISOname), ]
  
  
  df <- consumerPriceIndicesDF[order(consumerPriceIndicesDF[yearColumn]), ]
  df$area <- factor(df$area, levels = unique(as.character(df$area)) )
  
  # Plot index data by country for a particular month and year
  fig <- plot_ly(x = df[yearColumn][[1]], 
                 y = df$area, 
                 type = 'bar', 
                 orientation = 'h',
                 colors = 'YlOrRd') %>%
    layout(xaxis = list(autotypenumbers = 'strict', title = 'Consumer Prices'),
           yaxis = list(title = 'Country'),
           plot_bgcolor='#e5ecf6',
           title = paste('Consumer Prices, Food Indices, ', month, ' of ', year, sep = ''),
           xaxis = list(
             zerolinecolor = '#ffff',
             zerolinewidth = 2,
             gridcolor = 'ffff'),
           yaxis = list(
             zerolinecolor = '#ffff',
             zerolinewidth = 2,
             gridcolor = 'ffff'))
  print(fig)  
  htmlwidgets::saveWidget(as_widget(fig), paste(rawDataVisualizations, 'global_consumer_price_data.html', sep = '/'))
}

#' Visualizes the raw food security indicator information by country
#' 
#' @param itemCode The item code associated with an indicator
#' @param month The month being visualized
#' @param year The year being visualized
visualizeRawGlobalFoodSecurityIndicatorData <- function(itemCode, year) {
  print('Visualizing raw global food security indicator data')
  yearColumn = paste('y', year, sep = '')
  foodSecurityIndicatorsFile <- paste(dataFolder, paste('food_security_indicators', '.rds', sep = ''), sep = '/')
  foodSecurityIndicatorsDF <- readRDS(foodSecurityIndicatorsFile)
  foodSecurityIndicatorsDF <- foodSecurityIndicatorsDF[
    (foodSecurityIndicatorsDF$item_code == itemCode) &
      (!is.na(foodSecurityIndicatorsDF[yearColumn])), ]
  
  # Clean some of the columns in the raw data before visualizing.
  foodSecurityIndicatorsDF$area <- iconv(foodSecurityIndicatorsDF$area, from = 'UTF-8', to = 'ASCII//TRANSLIT')
  foodSecurityIndicatorsDF <- subset(foodSecurityIndicatorsDF, select = c('area', yearColumn))
  foodSecurityIndicatorsDF$area[foodSecurityIndicatorsDF$area == 'United States of America'] <- 'United States'
  foodSecurityIndicatorsDF$area[foodSecurityIndicatorsDF$area == 'Viet Nam'] <- 'Vietnam'
  foodSecurityIndicatorsDF[yearColumn] = as.numeric(foodSecurityIndicatorsDF[yearColumn][[1]])
  # Remove countries that have names that can't be converted to ASCII encoding.
  foodSecurityIndicatorsDF <- foodSecurityIndicatorsDF[
    (!is.na(foodSecurityIndicatorsDF$area)) & 
      (foodSecurityIndicatorsDF$area %in% iso3166$ISOname), ]
  
  
  df <- foodSecurityIndicatorsDF[order(foodSecurityIndicatorsDF[yearColumn]), ]
  df$area <- factor(df$area, levels = unique(as.character(df$area)) )
  
  fig <- plot_ly(x = df[yearColumn][[1]], 
                 y = df$area, 
                 type = 'bar', 
                 orientation = 'h',
                 colors = 'YlOrRd') %>%
    layout(xaxis = list(autotypenumbers = 'strict', title = 'Percentage of the population'),
           yaxis = list(title = 'Country'),
           plot_bgcolor='#e5ecf6',
           title = paste('Percentage of Children Under 5 who are stunted in the year ', year, sep = ''),
           xaxis = list(
             zerolinecolor = '#ffff',
             zerolinewidth = 2,
             gridcolor = 'ffff'),
           yaxis = list(
             zerolinecolor = '#ffff',
             zerolinewidth = 2,
             gridcolor = 'ffff'))
  print(fig)
  htmlwidgets::saveWidget(as_widget(fig), paste(rawDataVisualizations, 'global_food_indicator_data.html', sep = '/'))
}

#' Visualizes the processed consumer price data using the dygraph software
#' 
#' @param f The file containing the processed dataframe
#' @param itemCode The item code associated with an index
#' @param type The description of the index
visualizeProcessedConsumerPricesData <- function(f, itemCode, type) {
  print('Visualizing processed data for')
  df <- read.csv(f)
  df <- df[(df$IndicatorCode == itemCode) & (df$Value != naValue), ]
  if (nrow(df) == 0) {
    print('%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
    print('No data exists, skipping...')
    print('%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
  } else {
    country <- sub('-consumer-price-indices', '', file_path_sans_ext(basename(f)))
    description <- paste(df$Description[[1]], ' for ', country, sep = '')
    print(description)
    df$Date <- as.Date(df$Date, '%m-%d-%Y')
    df$Value <- as.numeric(df$Value)
    
    # Then you can create the xts necessary to use dygraph
    don <- xts(x = df$Value, order.by = df$Date)
    
    # Finally the plot
    p <- dygraph(don, main = description) %>%
      dyOptions(labelsUTC = TRUE, fillGraph=TRUE, fillAlpha=0.1, drawGrid = FALSE, colors=randomColor()) %>%
      dyRangeSelector() %>%
      dyCrosshair(direction = "vertical") %>%
      dyHighlight(highlightCircleSize = 5, highlightSeriesBackgroundAlpha = 0.2, hideOnMouseOut = FALSE)  %>%
      dyRoller(rollPeriod = 1) %>%
      dyAxis("x", label = "Time") %>%
      dyAxis("y", label = "Consumer Prices")
    
    print('Saving visualization to processed data visualizations folder')
    htmlwidgets::saveWidget(as_widget(p), paste(processedDataVisualizations, 'consumer_price_indices', type, paste(country, '.html', sep = ''), sep = '/'))
  }
}

#' Visualizes the processed food security indicator data using the dygraph software
#' 
#' @param f The file containing the processed dataframe
#' @param itemCode The item code associated with an indicator
#' @param type The description of the indicator
visualizeProcessedFoodSecurityIndicatorData <- function(f, itemCode, type) {
  print('Visualizing processed data for')
  df <- read.csv(f)
  df <- df[(df$IndicatorCode == itemCode) & (df$Value != naValue), ]
  if (nrow(df) == 0) {
    print('%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
    print('No data exists, skipping...')
    print('%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
  } else {
    unit <- ifelse(df$UnitOfMeasure[[1]] != '', paste(' (', df$UnitOfMeasure[[1]], ')', sep = ''), '')
    country <- sub('-food-security-indicators', '', file_path_sans_ext(basename(f)))
    description <- paste(df$Description[[1]], ' for ', country, sep = '')
    print(description)
    df$Year <- as.Date(ISOdate(df$Year, 1, 1))
    df$Value <- as.numeric(df$Value)
    # Then you can create the xts necessary to use dygraph
    don <- xts(x = df$Value, order.by = df$Year)
    
    # Finally the plot
    p <- dygraph(don, main = description) %>%
      dyOptions(labelsUTC = TRUE, fillGraph=TRUE, fillAlpha=0.1, drawGrid = FALSE, colors=randomColor()) %>%
      dyRangeSelector() %>%
      dyCrosshair(direction = "vertical") %>%
      dyHighlight(highlightCircleSize = 5, highlightSeriesBackgroundAlpha = 0.2, hideOnMouseOut = FALSE)  %>%
      dyRoller(rollPeriod = 1) %>%
      dyAxis("x", label = "Time") %>%
      dyAxis("y", label = paste("Indicator Value", unit, sep = ''))
    
    print('Saving visualization to processed data visualizations folder')
    htmlwidgets::saveWidget(as_widget(p), paste(processedDataVisualizations, 'food_security_indicators', type, paste(country, '.html', sep = ''), sep = '/'))
  }
}

#' Determines the raw s3 file path used when uploading the data to S3
#' 
#' @param file An existing file path
#' @param directory A directory to categorize the data in S3
#' @returns The s3 file path
#' @examples 
#' determineRawS3FilePath('raw_data/data.csv', 'specific_path_in_s3') => 'raw_data/specific_path_in_s3/data.csv'
determineProcessedS3FilePath <- function(file, suffix, directory) {
  folderStructure <- unlist(strsplit(file, split = '/'))
  s3FilePath <- paste(folderStructure[1], directory, sub(suffix, '', folderStructure[2]), sep = '/')
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

if (retrieveRawData) {
  unlink('raw_data/*')
  # Download and store data locally from the FAO
  downloadAndStoreDataFromFAO('Food_Security_Data_E_All_Data', 'food_security_indicators')
  downloadAndStoreDataFromFAO('FoodBalanceSheets_E_All_Data', 'food_balance_sheets')
  downloadAndStoreDataFromFAO('FoodBalanceSheetsHistoric_E_All_Data', 'historic_food_balance_sheets')
  downloadAndStoreDataFromFAO('Production_Crops_Livestock_E_All_Data', 'production_livestock_and_crops')
  downloadAndStoreDataFromFAO('ConsumerPriceIndices_E_All_Data', 'consumer_price_indices')
}

if (visualizeRawData) {
  if (visualizeRawConsumerPriceData) {
    itemCode <- 23013
    month <- 'January'
    year <- '2000'
    visualizeRawGlobalConsumerPriceData(itemCode, month, year)
  }
  if (visualizeRawFoodSecurityIndicatorData) {
    itemCode <- 21025
    year <- '2003'
    visualizeRawGlobalFoodSecurityIndicatorData(itemCode, year)
  }
}

if (processRawData) {
  if (processFoodIndicatorData) {
    unlink(paste('processed_data/*-food-security-indicators.*', sep = ''))
    foodSecurityFileName <- paste(dataFolder, paste('food_security_indicators', '.rds', sep = ''), sep = '/')
    foodSecurityDF <- readRDS(foodSecurityFileName)
    processFoodSecurityIndicatorData(foodSecurityDF)
  }
  if (processConsumerPriceData) {
    unlink(paste('processed_data/*-consumer-price-indices.*', sep = ''))
    consumerPriceIndices <- paste(dataFolder, paste('consumer_price_indices', '.rds', sep = ''), sep = '/')
    consumerPriceIndicesDF <- readRDS(consumerPriceIndices)
    processConsumerPriceIndicesData(consumerPriceIndicesDF)
  }
}

if (visualizeProcessedData) {
  if (visualizeConsumerPriceIndexData) {
    allFiles <- list.files(processedDataPath, full.names = TRUE, pattern = '*-consumer-price-indices.csv')
    lapply(allFiles, FUN = function(f) { visualizeProcessedConsumerPricesData(f, 23012, 'general_indices') })
    lapply(allFiles, FUN = function(f) { visualizeProcessedConsumerPricesData(f, 23013, 'food_indices') })
    lapply(allFiles, FUN = function(f) { visualizeProcessedConsumerPricesData(f, 23014, 'food_price_inflation') })
  }
  if (visualizeFoodSecurityIndicatorData) {
    allFiles <- list.files(processedDataPath, full.names = TRUE, pattern = '*-food-security-indicators.csv')
    lapply(allFiles, FUN = function(f) { visualizeProcessedFoodSecurityIndicatorData(f, 21031, 'food_supply_variability') })
    lapply(allFiles, FUN = function(f) { visualizeProcessedFoodSecurityIndicatorData(f, 210091, 'food_insecurity_population_percent') })
  }
}

if (uploadDataToS3) {
  if (uploadRawDataToS3) {
    print('Uploading raw consumer price indices data to S3')
    rawConsumerPriceIndexData <- 'raw_data/consumer_price_indices.csv'
    rawConsumerPriceIndexS3Data <- 'raw_data/consumer_price_indices/comsumer-price-indices.csv'
    storeDataInS3(rawConsumerPriceIndexData, rawConsumerPriceIndexS3Data)
    
    print('Uploading raw food security indicators data to S3')
    rawFoodSecurityIndicatorsData <- 'raw_data/food_security_indicators,csv'
    rawFoodSecurityIndicatorsS3Data <- 'raw_data/food_security_indicators/food-security-indicators.csv'
    storeDataInS3(rawFoodSecurityIndicatorsData, rawFoodSecurityIndicatorsS3Data)
  }
  if (uploadRawVisualizationsToS3) {
    print('Uploading raw consumer price indices visualizations to S3')
    rawConsumerPriceIndexData <- 'raw_data_visualizations/global_consumer_price_data.html'
    rawConsumerPriceIndexS3Data <- 'raw_data_visualizations/consumer_price_indices/global-consumer-price-data.html'
    storeDataInS3(rawConsumerPriceIndexData, rawConsumerPriceIndexS3Data)
    
    print('Uploading raw food security indicators visualizations to S3')
    rawFoodSecurityIndicatorsData <- 'raw_data_visualizations/global_food_indicator_data.html'
    rawFoodSecurityIndicatorsS3Data <- 'raw_data_visualizations/food_security_indicators/global-food-indicator-data.html'
    storeDataInS3(rawFoodSecurityIndicatorsData, rawFoodSecurityIndicatorsS3Data)
  }
  if (uploadProcessedDataToS3) {
    print('Uploading processed consumer price indices to S3')
    allFiles <- list.files(processedDataPath, full.names = TRUE, pattern = '*-consumer-price-indices.csv')
    lapply(allFiles, FUN = function(f) { storeDataInS3(f, determineProcessedS3FilePath(f, '-consumer-price-indices', 'consumer_price_indices')) })
    
    print('Uploading processed food security indicators to S3')
    allFiles <- list.files(processedDataPath, full.names = TRUE, pattern = '*-food-security-indicators.csv')
    lapply(allFiles, FUN = function(f) { storeDataInS3(f, determineProcessedS3FilePath(f, '-food-security-indicators', 'food_security_indicators')) })
  }
  if (uploadProcessedVisualizationsToS3) {
    print('Uploading processed visualizations to S3')
    allFiles <- list.files(processedDataVisualizations, full.names = TRUE, pattern = '*.html', recursive = TRUE)
    lapply(allFiles, FUN = function(f) { storeDataInS3(f, f) })
  }
}

# ------------------------------------------------------------------------------
