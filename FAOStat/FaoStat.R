# Retrieve FAO data
library('FAOSTAT')
dataFolder <- 'raw_data'
if (dir.exists(dataFolder) == FALSE) {
  dir.create(dataFolder, )
}

downloadAndStoreDataFromFAO = function(bulkDataFile, rdsFileName) {
  urlBulkUrl <- "http://fenixservices.fao.org/faostat/static/bulkdownloads"
  bulkData <- file.path(urlBulkUrl, paste(bulkDataFile, '.zip', sep = '' ))
  download_faostat_bulk(url_bulk = bulkData, data_folder = dataFolder)
  
  bulkData <- read_faostat_bulk(paste(dataFolder, paste(bulkDataFile, '.zip', sep = ''), sep = '/'))
  print(head(bulkData))
  
  # Save to RDS for faster access later
  saveRDS(bulkData, paste(dataFolder, paste(rdsFileName, '.rds', sep = ''), sep = '/'))
}

downloadAndStoreDataFromFAO('Food_Security_Data_E_All_Data', 'food_security_indicators')
downloadAndStoreDataFromFAO('FoodBalanceSheets_E_All_Data', 'food_balance_sheets')
downloadAndStoreDataFromFAO('FoodBalanceSheetsHistoric_E_All_Data', 'historic_food_balance_sheets')
downloadAndStoreDataFromFAO('Production_Crops_Livestock_E_All_Data', 'production_livestock_and_crops')
downloadAndStoreDataFromFAO('ConsumerPriceIndices_E_All_Data', 'consumer_prices_indicies')
# This one is having problems
# downloadAndStoreDataFromFAO('Trade_CropsLivestock_E_All_Data', 'trade_crop_livestock')

# Store raw FAO data in S3

# Clean FAO data

# Store cleaned FAO data in S3
