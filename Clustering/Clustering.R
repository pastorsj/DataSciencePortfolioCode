# Clustering
library(tidyverse)
library(philentropy)
library(plotly)
library(factoextra)
library(dbscan)
library(stats)
library(svglite)


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

clusteredDataPath <- 'clustered_data/lockdown_results'
clusteredDataVisualizations = 'clustered_data_visualizations/lockdown_results'

createDirectoryIfNotExists(clusteredDataPath)
createDirectoryIfNotExists(clusteredDataVisualizations)


# Create large dataset that combines all record data together, joined on the first date of each month (per state, per day)
# Data includes
# Household surveys
# Lockdown data
# Fred data employment in each state
# Covid data

combineProcessedData <- TRUE
cleanProcessedData <- TRUE
clusterRecordData <- TRUE

# Combining the data
# Algorithm
# Start with household surveys, all, normalized
# On a per date basis, find whether at the beginning of the month, they were under lockdown (true or false)
# then, find the exact number of covid cases that day per state
# then, find the fred employment data for that month per state

householdSurveyData <- '../DataSourcing/processed_data/consolidated_survey_data/standard/all'
lockdownData <- '../DataSourcing/processed_data/lockdown_data'


consolidateSurveyData <- function(df) {
  consolidated.df <- df %>% 
    pivot_wider(
      names_from = c(Characteristic, Topic), 
      names_glue = "{.value}_{Topic}_{Characteristic}",
      values_from = c(Total, Enough.of.the.kinds.of.food.wanted, Enough.food.but.not.always.the.kinds.wanted, Sometimes.not.enough.to.eat, Often.not.enough.to.eat, Did.not.report)
    )
  return(consolidated.df)
}

retrieveHouseholdSurveyData <- function() {
  allFiles <- list.files(householdSurveyData, full.names = TRUE, pattern = '*-normalized.csv')
  df <- data.frame()
  new.dfs <- lapply(allFiles, FUN = function(f) consolidateSurveyData(read.csv(f)))
  for (n.df in new.dfs) {
    df <- rbind(df, n.df)
  }
  print('Retrieved household survey data and combined')
  return(df)
}

matchLockdownData <- function(x, lockdownDf) {
  stateName <- state.name[state.abb == x['State']]
  reduced.df <- lockdownDf[lockdownDf$State == stateName, ]
  res <- reduced.df[
          (strftime(as.Date(reduced.df$Date), '%Y-%m') == strftime(as.Date(x['Date']), '%Y-%m')), ]$InLockdown
  if (identical(res, character(0))) {
    res <- FALSE
  }
  return(res)
}

combineWithLockdownData <- function(df) {
  allFiles <- list.files(lockdownData, full.names = TRUE, pattern = '*.csv')
  lockdownDf <- data.frame()
  new.dfs <- lapply(allFiles, FUN = function(f) read.csv(f))
  for (n.df in new.dfs) {
    lockdownDf <- rbind(lockdownDf, n.df)
  }
  df$InLockdown <- apply(df[, c('Date', 'State')], 1, FUN = function(x) matchLockdownData(x, lockdownDf))
  return(df)
}

plotClusters <- function(df, scaled.df, clusterName, title, filename) {
  pc <- prcomp(scaled.df, rank. = 3)
  components <- pc[["x"]]
  components <- data.frame(components)
  components$PC2 <- -components$PC2
  components$PC3 <- -components$PC3
  components$Cluster <- df[clusterName][[1]]
  components$InLockdown <- df$InLockdown
  
  fig <- plot_ly(components, 
                 x = components$PC1, 
                 y = components$PC2, 
                 z = components$PC3, 
                 color = components$Cluster, 
                 text = components$InLockdown, 
                 colors = c("#2E9FDF", "#00AFBB", "#E7B800", "#820000", "#82fb6f", "#8947c2") 
                 ) %>%
    add_markers(size = 12)
  fig <- fig %>%
    layout(
      title = title,
      scene = list(bgcolor = "#e5ecf6")
    )
  print(fig)
  htmlwidgets::saveWidget(as_widget(fig), paste(clusteredDataVisualizations, paste(filename, '_3d.html', sep = ''), sep = '/'))
  
  fig2 <- plot_ly(components, 
                 x = components$PC1, 
                 y = components$PC2, 
                 color = components$Cluster, 
                 text = components$InLockdown, 
                 colors = c("#2E9FDF", "#00AFBB", "#E7B800", "#820000", "#82fb6f", "#8947c2") 
  ) %>%
    add_markers(size = 12)
  fig2 <- fig2 %>%
    layout(
      title = title,
      scene = list(bgcolor = "#e5ecf6")
    )
  print(fig2)
  htmlwidgets::saveWidget(as_widget(fig2), paste(clusteredDataVisualizations, paste(filename, '_2d.html', sep = ''), sep = '/'))
  
  print('Statistics')
  stat.df <- df %>%
    group_by_at(clusterName) %>%
    summarize(TotalInLockdown = sum((InLockdown == TRUE) | (InLockdown == 'True')), TotalNotInLockdown = sum((InLockdown == FALSE) | (InLockdown == 'False'))) %>%
    ungroup()
  
  print(stat.df)
  print('Writing statistics to a csv')
  write.csv(as.data.frame(stat.df), paste(clusteredDataPath, paste(filename, '_statistics.csv', sep = ''), sep = '/'))
}


calculateDistanceMatrices <- function(df, scaled.df) {
  print('Calculating euclidean distance matrix')
  dist.euclidean <- dist(scaled.df, method = "euclidean")
  write.csv(as.matrix(dist.euclidean), paste(clusteredDataPath, 'euclidean_distance.csv', sep = '/'))

  print('Visualizing euclidean distance matrix')
  png(paste(clusteredDataVisualizations, 'euclidean_distance_matrix_full.png', sep = '/'))
  p.d <- fviz_dist(
    dist.euclidean,
    order = TRUE,
    lab_size = NULL,
    show_labels = FALSE,
    gradient = list(low = "red", mid = "white", high = "blue")
  )
  print(p.d)
  dev.off()
  
  print('hclust with euclidean distance matrix')
  fitWithEuclidean <- hclust(dist.euclidean, method = "ward.D2")
  png(paste(clusteredDataVisualizations, 'euclidean_distance_dendrogram_full.png', sep = '/'), width = 1200)
  p <- plot(fitWithEuclidean, labels = FALSE, main = "Cluster Dendrogram using Euclidean Distance")
  print(p)
  dev.off()
  
  sampled.values <- sample(nrow(scaled.df), 100)
  dist.euclidean.r = dist(scaled.df[sampled.values, ], method = "euclidean")
  df.sampled <- df[sampled.values, ]
  
  print('hclust with randomly sample euclidean distance matrix')
  png(paste(clusteredDataVisualizations, 'euclidean_distance_dendrogram_sample.png', sep = '/'), width = 1200)
  fitWithEuclidean <- hclust(dist.euclidean.r, method = "ward.D2")
  p <- plot(fitWithEuclidean, labels = df.sampled$InLockdown, main = "Cluster Dendrogram using Euclidean Distance")
  print(p)
  dev.off()
  
  print('Attempting to plot silhouette method for euclidean distance metric')
  p <- fviz_nbclust(
    as.matrix(scaled.df), 
    kmeans, 
    k.max = 10,
    method = "silhouette",
    diss = dist.euclidean
  ) + labs(title = "Silhouette Method (Euclidean)")
  ggsave(paste(clusteredDataVisualizations, 'silhouette_euclidean_distance.svg', sep = '/'))
  print(p)
  dev.off()
  
  print('Attempting to plot gap statistic method for euclidean distance metric')
  p <- fviz_nbclust(
    as.matrix(scaled.df), 
    kmeans,
    k.max = 10,
    method = "gap_stat",
    diss = dist.euclidean
  ) + labs(title = "Gap Statistic Method (Euclidean)")
  ggsave(paste(clusteredDataVisualizations, 'gap_euclidean_distance.svg', sep = '/'))
  print(p)
  dev.off()
  
  print('Calculating manhattan distance matrix')
  dist.manhattan <- dist(scaled.df, method = "manhattan")
  write.csv(as.matrix(dist.manhattan), paste(clusteredDataPath, 'manhattan_distance.csv', sep = '/'))
  
  print('Visualizing manhattan distance matrix')
  png(paste(clusteredDataVisualizations, 'manhattan_distance_matrix.png', sep = '/'))
  p.d <- fviz_dist(
    dist.manhattan,
    order = TRUE,
    lab_size = NULL,
    show_labels = FALSE,
    gradient = list(low = "red", mid = "white", high = "blue")
  )
  print(p.d)
  dev.off()
  
  print('hclust with manhattan distance matrix')
  fitWithManhattan <- hclust(dist.manhattan, method = "ward.D2")
  png(paste(clusteredDataVisualizations, 'manhattan_distance_dendrogram.png', sep = '/'), width = 1200)
  p <- plot(fitWithManhattan, labels = FALSE, main = "Cluster Dendrogram using Manhattan Distance")
  print(p)
  dev.off()
  
  sampled.values <- sample(nrow(scaled.df), 100)
  dist.manhattan.r = dist(scaled.df[sampled.values, ], method = "manhattan")
  df.sampled <- df[sampled.values, ]
  
  print('hclust with randomly sample euclidean distance matrix')
  png(paste(clusteredDataVisualizations, 'manhattan_distance_dendrogram_sample.png', sep = '/'), width = 1200)
  fitWithManhattan <- hclust(dist.manhattan.r, method = "ward.D2")
  p <- plot(fitWithManhattan, labels = df.sampled$InLockdown, main = "Cluster Dendrogram using Manhattan Distance")
  print(p)
  dev.off()
  
  print('Attempting to plot silhouette method for manhattan distance metric')
  p <- fviz_nbclust(
    as.matrix(scaled.df), 
    kmeans, 
    k.max = 10,
    method = "silhouette",
    diss = dist.manhattan
  ) + labs(title = "Silhouette Method (Manhattan)")
  ggsave(paste(clusteredDataVisualizations, 'silhouette_manhattan_distance.svg', sep = '/'))
  print(p)
  dev.off()
  
  print('Attempting to plot gap statistic method for manhattan distance metric')
  p <- fviz_nbclust(
    as.matrix(scaled.df), 
    kmeans,
    k.max = 10,
    method = "gap_stat",
    diss = dist.manhattan
  ) + labs(title = "Gap Statistic Method (Manhattan)")
  ggsave(paste(clusteredDataVisualizations, 'gap_manhattan_distance.svg', sep = '/'))
  print(p)
  dev.off()
  
  print('Calculating cosine similarity distance matrix')
  dist.cosine.similarity <- distance(scaled.df, method = "cosine")
  write.csv(as.matrix(dist.cosine.similarity), paste(clusteredDataPath, 'cosine_distance.csv', sep = '/'))
  
  print('Visualizing cosine similarity distance matrix')
  png(paste(clusteredDataVisualizations, 'cosine_distance_matrix.png', sep = '/'))
  p.d <- fviz_dist(
    as.dist(dist.cosine.similarity),
    order = TRUE,
    lab_size = NULL,
    show_labels = FALSE,
    gradient = list(low = "red", mid = "white", high = "blue")
  )
  print(p.d)
  dev.off()
  
  print('hclust with cosine distance matrix')
  png(paste(clusteredDataVisualizations, 'cosine_distance_dendrogram_full.png', sep = '/'), width = 1200)
  fitWithCosine <- hclust(as.dist(dist.cosine.similarity), method = "ward.D2")
  p <- plot(fitWithCosine, labels = FALSE, main = "Cluster Dendrogram using Cosine Similarity Distance")
  print(p)
  dev.off()
  
  sampled.values <- sample(nrow(scaled.df), 100)
  dist.cosine.r = distance(scaled.df[sampled.values, ], method = "cosine")
  df.sampled <- df[sampled.values, ]
  
  print('hclust with randomly sample cosine distance matrix')
  png(paste(clusteredDataVisualizations, 'cosine_distance_dendrogram_sample.png', sep = '/'), width = 1200)
  fitWithCosine <- hclust(as.dist(dist.cosine.r), method = "ward.D2")
  p <- plot(fitWithCosine, labels = df.sampled$InLockdown, main = "Cluster Dendrogram using Cosine Similarity Distance")
  print(p)
  dev.off()
  
  print('Attempting to plot silhouette method for cosine distance metric')
  p <- fviz_nbclust(
    as.matrix(scaled.df), 
    kmeans, 
    k.max = 10,
    method = "silhouette",
    diss = as.dist(dist.cosine.similarity)
  ) + labs(title = "Silhouette Method (Cosine Similarity)")
  ggsave(paste(clusteredDataVisualizations, 'silhouette_cosine_distance.svg', sep = '/'))
  print(p)
  dev.off()
  
  print('Attempting to plot gap statistic method for cosine distance metric')
  p <- fviz_nbclust(
    as.matrix(scaled.df), 
    kmeans,
    k.max = 10,
    method = "gap_stat",
    diss = as.dist(dist.cosine.similarity)
  ) + labs(title = "Gap Statistic Method (Cosine Similarity)")
  ggsave(paste(clusteredDataVisualizations, 'gap_cosine_distance.svg', sep = '/'))
  print(p)
  dev.off()
}

runKMeansClustering <- function(df, scaled.df) {
  # Try K = 2
  k <- 2
  k.2 <- kmeans(scaled.df, k)
  print('Plotting k = 2 cluster')
  p <- fviz_cluster(k.2, data = scaled.df,
                   palette = c("#2E9FDF", "#00AFBB"), 
                   geom = "point",
                   ellipse.type = "convex", 
                   ggtheme = theme_bw()
  ) + labs(title = "K Means Clusters (k=2)")
  ggsave(paste(clusteredDataVisualizations, 'kmeans-2-clusters.svg', sep = '/'))
  print(p)
  dev.off()
  df$KMeansCluster2 = k.2$cluster
  plotClusters(df, scaled.df, 'KMeansCluster2', 'Plot of K-Means Clusters (k=2)', 'k_means_2')

    # Try K = 3
  k <- 3
  k.3 <- kmeans(scaled.df, k)
  print('Plotting k = 3 cluster')
  p <- fviz_cluster(k.3, data = scaled.df,
                    palette = c("#2E9FDF", "#00AFBB", "#E7B800"), 
                    geom = "point",
                    ellipse.type = "convex", 
                    ggtheme = theme_bw()
  ) + labs(title = "K Means Clusters (k=3)")
  ggsave(paste(clusteredDataVisualizations, 'kmeans-3-clusters.svg', sep = '/'))
  print(p)
  dev.off()
  df$KMeansCluster3 = k.3$cluster
  plotClusters(df, scaled.df, 'KMeansCluster3', 'Plot of K-Means Clusters (k=3)', 'k_means_3')
  
  # Try K = 6
  k <- 6
  k.6 <- kmeans(scaled.df, k)
  print('Plotting k = 6 cluster')
  p <- fviz_cluster(k.6, data = scaled.df,
                    palette = c("#2E9FDF", "#00AFBB", "#E7B800", "#820000", "#82fb6f", "#8947c2"), 
                    geom = "point",
                    ellipse.type = "convex", 
                    ggtheme = theme_bw()
  ) + labs(title = "K Means Clusters (k=6)")
  ggsave(paste(clusteredDataVisualizations, 'kmeans-6-clusters.svg', sep = '/'))
  print(p)
  dev.off()
  df$KMeansCluster6 = k.6$cluster
  plotClusters(df, scaled.df, 'KMeansCluster6', 'Plot of K-Means Clusters (k=6)', 'k_means_6')
  
  return(df)
}

runDensityClustering <- function(df, scaled.df) {
  dfmatrix <- as.matrix(scaled.df)
  kNNdistplot(dfmatrix, k = 5)
  abline(h = 7)
  ggsave(paste(clusteredDataVisualizations, 'knn_distance_plot.svg', sep = '/'))
  dev.off()
  
  db <- dbscan(scaled.df, eps = 7, MinPts = 10)
  hullplot(dfmatrix, db$cluster)
  ggsave(paste(clusteredDataVisualizations, 'density_clustering.svg', sep = '/'))
  dev.off()
  
  df$DensityCluster <- db$cluster
  plotClusters(df, scaled.df, 'DensityCluster', 'Plot of Density Clusters', 'density_clusters')
  return(df)
}

# Output the data, save to csv
if (combineProcessedData) {
  df <- retrieveHouseholdSurveyData()
  df <- combineWithLockdownData(df)
  # Write to csv
  print('Combined processed data and wrote to csv')
  write.csv(df, file = "combined_processed_data.csv", row.names = FALSE)
}

# Remove labels and dates, save to csv
if (cleanProcessedData) {
  df <- read.csv('combined_processed_data.csv')
  # Remove columns
  df <- subset(df, select = -c(State, Week, Date, Total_total_total))
  print('Removed headers')
  write.csv(df, file = paste(clusteredDataPath, "processed_record_data.csv", sep = '/'), row.names = FALSE)
}

# Cluster the data

if (clusterRecordData) {
  df <- read.csv(paste(clusteredDataPath, 'processed_record_data.csv', sep = '/'))
  # Remove in lockdown label
  cleaned.df <- subset(df, select = -c(InLockdown))
  scaled.df <- scale(cleaned.df)
  print('Running heirarchical clustering')
  calculateDistanceMatrices(df, scaled.df)
  print('Running k means clustering')
  df <- runKMeansClustering(df, scaled.df)
  print('Running density based clustering')
  df <- runDensityClustering(df, scaled.df)
  print('Plotting clusters')
  write.csv(df, 'clustered_record_data.csv')
}

# Decide what to summarize?
