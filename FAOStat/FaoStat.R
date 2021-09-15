library('FAOSTAT')
library(tidyverse)
library(plotly)

dataFolder <- 'raw_data'
# Create the directory if it doesn't exist.
if (dir.exists(dataFolder) == FALSE) {
  dir.create(dataFolder, )
}

retrieveRawData <- FALSE
visualizeRawData <- TRUE

# Retrieve FAO data
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

visualizeData <- function(df) {
  p <- ggplot(df,aes(x = area, y = y20182020)) + 
    geom_point() +
    labs(title = "Number of people undernourished (3 year average)", x = "Country", y = "Total (millions)") +
    scale_x_discrete(labels = NULL, breaks = NULL)
  print(p)
  # Trying things out with plotly
  p <- ggplotly(p, tooltip="tooltip")
  print(p)
}

if (retrieveRawData) {
  # Download and store data locally from the FAO
  downloadAndStoreDataFromFAO('Food_Security_Data_E_All_Data', 'food_security_indicators')
  downloadAndStoreDataFromFAO('FoodBalanceSheets_E_All_Data', 'food_balance_sheets')
  downloadAndStoreDataFromFAO('FoodBalanceSheetsHistoric_E_All_Data', 'historic_food_balance_sheets')
  downloadAndStoreDataFromFAO('Production_Crops_Livestock_E_All_Data', 'production_livestock_and_crops')
  downloadAndStoreDataFromFAO('ConsumerPriceIndices_E_All_Data', 'consumer_prices_indices')
}

if (visualizeRawData) {
  code <- 210011
  year <- 'y20182020'
  df <- readRDS(paste(dataFolder, paste('food_security_indicators', '.rds', sep = ''), sep = '/'))
  df <- df[df$item_code == code, c('area', 'y20182020')]
  df$tooltip <- paste('Country:', df$area, '\n', 'Total:', df$y20182020, sep = '')
  print(head(df))
  visualizeData(df)
}




# Next Steps
# Store raw FAO data in S3

# Clean FAO data

# Store cleaned FAO data in S3
