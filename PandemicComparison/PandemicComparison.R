# Pandemic Comparison
library(pdftools)
library(tm)
library(wordcloud)
library(wordcloud2)
library(textstem)
library(RColorBrewer)
library(webshot)
library(htmlwidgets)
library(aws.s3)
library(stringr)
library(dplyr)
webshot::install_phantomjs()


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

rawDataPath <- 'raw_data'
rawDataVisualizations <- 'raw_data_visualizations'
processedDataPath <- 'processed_data'
processedDataVisualizations = 'processed_data_visualizations'

createDirectoryIfNotExists(rawDataPath)
createDirectoryIfNotExists(rawDataVisualizations)
createDirectoryIfNotExists(processedDataPath)
createDirectoryIfNotExists(processedDataVisualizations)

covidCorpus <- 'covid_corpus'
ebolaCorpus <- 'ebola_corpus'
droughtCorpus <- 'drought_corpus'
locustsCorpus <- 'locusts_corpus'

extractAndProcessData <- TRUE
storeInS3 <- FALSE

extractCorpusDataAndProcess <- function(corpus_path, type) {
  allFiles <- list.files(corpus_path, full.names = TRUE, pattern = '*.pdf')
  print(allFiles)
  corpus <- vector()
  for (file in allFiles) {
    pdfText <- pdftools::pdf_text(file)
    pdfText <- paste(unlist(pdfText), collapse = ' ')
    corpus <- append(corpus, pdfText)
  }
  vcorpus <- VCorpus(VectorSource(corpus))
  
  dtm.raw <- DocumentTermMatrix(vcorpus)
  cleaned_matrix.raw <- as.matrix(removeSparseTerms(dtm.raw, 0.99))
  consolidatedMatrix.raw <- sort(colSums(cleaned_matrix.raw), decreasing = TRUE)
  df.raw <- data.frame(words = names(consolidatedMatrix.raw), freq = consolidatedMatrix.raw)
  
  print('Writing raw data to file')
  write.csv(data.frame(cleaned_matrix.raw), paste('raw_data/', type, '_dtm.csv', sep = ''))
  
  w.raw <- wordcloud2(df.raw, size = 2)
  print('Attempting to save wordcloud as a raw data visualization')
  saveWidget(w.raw, paste('raw_data_visualizations/', type, '_wordcloud.html', sep = ''), selfcontained = F)
  

  
  # Clean the data as much as possible
  vcorpus <- tm_map(vcorpus, removePunctuation)
  vcorpus <- tm_map(vcorpus, removeNumbers)
  vcorpus <- tm_map(vcorpus, removeWords, stopwords("english"))
  vcorpus <- tm_map(vcorpus, content_transformer(tolower))
  vcorpus <- tm_map(vcorpus, stripWhitespace)
  vcorpus <- tm_map(vcorpus, lemmatize_words)

  dtm <- DocumentTermMatrix(vcorpus, control = list(wordLengths = c(3, 20)))
  text <- apply(removeSparseTerms(dtm, 0.99), 1, function(x) paste(rep(names(x), x), collapse = " "))
  df.dtm <- as.data.frame(text)
  df.dtm$link <- allFiles
  df.dtm$title <- allFiles
  df.dtm$topic <- type
  df.dtm$text <- gsub("[[:punct:]]", "", df.dtm$text)
  df.dtm$text <- gsub("\\b\\w{1,2}\\s", "", df.dtm$text)
  
  write.csv(df.dtm, paste('processed_data/', type, '_list.csv', sep = ''), row.names = FALSE)
  
  cleaned_matrix <- as.matrix(removeSparseTerms(dtm, 0.99))
  consolidatedMatrix <- sort(colSums(cleaned_matrix), decreasing = TRUE)
  df <- data.frame(words = names(consolidatedMatrix), freq = consolidatedMatrix)
  
  print('Writing processed data to file')
  write.csv(data.frame(cleaned_matrix), paste('processed_data/', type, '_dtm.csv', sep = ''))
  
  w <- wordcloud2(df, size = 2)
  print('Attempting to save wordcloud as a processed data visualization')
  saveWidget(w, paste('processed_data_visualizations/', type, '_wordcloud.html', sep = ''), selfcontained = F)
  
  return(df.dtm)
}



#' Stores a file in S3
#' 
#' @param file A file
#' @param directory The inner directory used to store the data in S3
storeDataInS3 <- function(file, directory) {
  folderStructure <- unlist(strsplit(file, split = '/'))
  s3FilePath <- paste(folderStructure[1], directory, folderStructure[2], sep = '/')
  print('Storing file in s3')
  print(s3FilePath)
  put_object(file = file, object = s3FilePath, bucket = 'datastore.portfolio.sampastoriza.com')
  print('Uploaded file to S3 successfully')
}

if (extractAndProcessData) {
  cleaned.df <- extractCorpusDataAndProcess(covidCorpus, 'covid')
  cleaned.df <- rbind(cleaned.df, extractCorpusDataAndProcess(ebolaCorpus, 'ebola'))
  cleaned.df <- rbind(cleaned.df, extractCorpusDataAndProcess(droughtCorpus, 'drought'))
  cleaned.df <- rbind(cleaned.df, extractCorpusDataAndProcess(locustsCorpus, 'locusts'))
  
  write.csv(cleaned.df, 'processed_data/cleaned_corpus_data.csv', row.names = FALSE)
}

if (storeInS3) {
  print('Uploading raw dtm data to S3')
  allFiles <- list.files(rawDataPath, full.names = TRUE, pattern = '*.csv')
  lapply(allFiles, FUN = function(f) { storeDataInS3(f, 'corpus_data') })
  
  print('Uploading raw data visualizations to S3')
  allFiles <- list.files(rawDataVisualizations, full.names = TRUE, pattern = '*.html')
  lapply(allFiles, FUN = function(f) { storeDataInS3(f, 'corpus_data') })
  
  print('Uploading processed dtm data to S3')
  allFiles <- list.files(processedDataPath, full.names = TRUE, pattern = '*.csv')
  lapply(allFiles, FUN = function(f) { storeDataInS3(f, 'corpus_data') })
  
  print('Uploading processed data visualizations to S3')
  allFiles <- list.files(processedDataVisualizations, full.names = TRUE, pattern = '*.html')
  lapply(allFiles, FUN = function(f) { storeDataInS3(f, 'corpus_data') })
}
