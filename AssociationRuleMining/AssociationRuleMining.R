##################
## NOTE: Some R packages
## cause trouble with each other
## when loaded at the same time
##
## SOLUTION: use detach
##
## Example: igraph and Statnet packages 
## cause some problems when loaded at the same time. 
## It is best to detach one before loading the other.
## library(igraph)          TO LOAD
## detach(package:igraph)   TO DETACH
##
################################################################

library(rlang)
library(usethis)
library(devtools)
library(base64enc)
library(RCurl)
library(networkD3)
library(tidyverse)
library(plyr)
library(dplyr)
library(ggplot2)
library(arules)
library(arulesViz)
library(plotly)
library(igraph)
library(htmltools)
library(shiny)
library(shinythemes)
library(aws.s3)

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

armDataPath <- 'arm_data/search_data'
armDataVisualizations <- 'arm_data_visualizations/search_data'

createDirectoryIfNotExists(armDataPath)
createDirectoryIfNotExists(armDataVisualizations)

processedSearchData <- '../DataSourcing/processed_data/search_results/cleaned_search_data.csv'
processedPdfData <- '../PandemicComparison/processed_data/corpus_data/cleaned_corpus_data.csv'

keywords <- c('covid', 'food', 'drought', 'security', 'utilization', 'stability', 'malnutrition', 'ebola', 'locust')

df.search <- read.csv(processedSearchData)
df.pdf <- read.csv(processedPdfData)
df.combined <- rbind(df.search, df.pdf[df.pdf$topic == 'ebola',])

write.csv(df.combined, paste(armDataPath, 'combined_search_data.csv', sep = '/'), row.names = FALSE)

data.transactions <- paste(df.combined$text, sep = '\n')
write(data.transactions, paste(armDataPath, 'search_transactions.txt', sep = '/'))

# Read Transactions
trans <- read.transactions(
  paste(armDataPath, 'search_transactions.txt', sep = '/'), 
  format = "basket",
  rm.duplicates = TRUE
)

### Frequency plot to get a sense of the transaction data
itemFrequencyPlot(trans, topN = 20,  cex.names = 1)

### Run Apriori Algorithm
rules <- arules::apriori(
  trans, 
  parameter = list(supp = 0.04,
                   conf = 0.8,
                   maxlen = 2,
                   minlen = 2))
rules <- subset(rules, subset = lift > 1.5)
rules <- rules[!is.redundant(rules)]
signficant.rules <- rules[!is.significant(rules, 
                               trans, 
                               method = "fisher", 
                               adjust = 'bonferroni')]
# Attempt to focus attention on key words
(filtered.rules <- subset(signficant.rules, subset = 
                            (rhs %pin% 'ebola') | (rhs %pin% 'covid') | (rhs %pin% 'drought') | (rhs %pin% 'locust') | (rhs %pin% 'food') | (rhs %pin% 'security') | (rhs %pin% 'nutrition') | (rhs %pin% 'stability') | (rhs %pin% 'utilization') |
                            (lhs %pin% 'ebola') | (lhs %pin% 'covid') | (lhs %pin% 'drought') | (lhs %pin% 'locust') | (lhs %pin% 'food') | (lhs %pin% 'security') | (lhs %pin% 'nutrition') | (lhs %pin% 'stability') | (lhs %pin% 'utilization')
))
inspect(filtered.rules)

rules <- filtered.rules
######################

##  Sort by Confidence
rules.conf <- sort(rules, by = "confidence", decreasing=TRUE)
inspect(rules.conf[1:15])
df.conf <- DATAFRAME(rules.conf[1:15], setStart = '', setEnd = '', separate = TRUE)
write.csv(df.conf, paste(armDataPath, 'top_confidence_rules.csv', sep = '/'), row.names = FALSE)

## Sort by Support
rules.sup <- sort(rules, by = "support", decreasing = TRUE)
inspect(rules.sup[1:15])
df.sup <- DATAFRAME(rules.sup[1:15], setStart = '', setEnd = '', separate = TRUE)
write.csv(df.sup, paste(armDataPath, 'top_support_rules.csv', sep = '/'), row.names = FALSE)

## Sort by Lift
rules.lift <- sort(rules, by = "lift", decreasing = TRUE)
inspect(rules.lift[1:15])
df.lift <- DATAFRAME(rules.lift[1:15], setStart = '', setEnd = '', separate = TRUE)
write.csv(df.lift, paste(armDataPath, 'top_lift_rules.csv', sep = '/'), row.names = FALSE)
######################

plotRules <- function(rules.plot, type) {
  ### Plot graph of rules by lift, confidence, and support
  subrules <- head(rules.plot, n = 500, by = "lift")
  p <- plot(subrules, engine = "plotly", main = 'Plot of lift vs confidence vs support')
  htmlwidgets::saveWidget(as_widget(p), paste(armDataVisualizations, paste(type, '_rules_lcs.html', sep = ''), sep = '/'))
  ######################
  
  ### Plot network of rules using visNetwork
  p.v <- plot(rules.plot, method = "graph", engine = "htmlwidget", max = 300)
  htmlwidgets::saveWidget(as_widget(p.v), paste(armDataVisualizations, paste(type, '_rules_viz_network.html', sep = ''), sep = '/'))
  ######################
  
  ### Begin process of transformation for network d3
  df.2 <- DATAFRAME(rules.plot, setStart = '', setEnd = '', separate = TRUE)
  
  ## Convert to char
  df.2$LHS <- as.character(df.2$LHS)
  df.2$RHS <- as.character(df.2$RHS)
  
  write.csv(df.2, paste(armDataPath, paste(type, '_network_data.csv', sep = ''), sep = '/'), row.names = FALSE)
  
  rules.clean <- df.2[c(1,2,3)]
  names(rules.clean) <- c("SourceName", "TargetName", "Weight")
  edgeList <- rules.clean
  (graph.rules <- igraph::simplify(igraph::graph.data.frame(edgeList, directed = TRUE)))
  
  ### Plot network of rules using plot
  graph.layout <- layout.fruchterman.reingold(graph.rules)
  png(paste(armDataVisualizations, paste(type, '_basic_network.png', sep = ''), sep = '/'), width = 2000, height = 1500)
  plot(igraph::graph.data.frame(edgeList, directed = TRUE),
             edge.arrow.size = 0.3,
             vertex.color="lightblue",
             layout=graph.layout,
             edge.arrow.size=.5,
             vertex.label.cex=1,
             edge.curved=0.2,
             vertex.label.color="black",
             edge.weight=5,
             rescale = TRUE
        )
  dev.off()
  
  ## Build Node and Edge List
  nodeList <- data.frame(ID = c(0:(igraph::vcount(graph.rules) - 1)), 
                         nName = igraph::V(graph.rules)$name)
  
  nodeList <- cbind(nodeList, nodeDegree=igraph::degree(graph.rules, 
                                                         v = igraph::V(graph.rules), mode = "all"))
  nodeList <- cbind(nodeList, fontSize = ifelse(igraph::V(graph.rules)$name %in% keywords, 30, 12))
  
  between.ness <- igraph::betweenness(graph.rules, 
                                     v = igraph::V(graph.rules), 
                                     directed = TRUE) 
  
  (nodeList <- cbind(nodeList, nodeBetweenness = between.ness))
  
  getNodeID <- function(x){
    which(x == igraph::V(graph.rules)$name) - 1  #IDs start at 0
  }
  
  edgeList <- plyr::ddply(
    rules.clean, .variables = c("SourceName", "TargetName" , "Weight"), 
    function (x) data.frame(SourceID = getNodeID(x$SourceName), 
                            TargetID = getNodeID(x$TargetName)))
  
  MyClickScript <- 
    '      d3.select(this).select("circle").transition()
  .duration(750)
  .attr("r", 30)'
  
  d3.network <- networkD3::forceNetwork(
    Links = edgeList,
    Nodes = nodeList,
    Source = "SourceID",
    Target = "TargetID",
    Value = "Weight",
    NodeID = "nName",
    Group = "nodeDegree",
    zoom = TRUE, 
    bounded = T,
    clickAction = MyClickScript,
    opacityNoHover = 1,
    fontSize = nodeList$fontSize
  ) 
  
  networkD3::saveNetwork(d3.network, 
                         paste(armDataVisualizations, paste(type, '_d3-network.html', sep = ''), sep = '/'), 
                         selfcontained = TRUE)
  ######################
  
  ### Build Sankey Network
  d3.sankeynetwork  <- sankeyNetwork(Links = edgeList,
                                    Nodes = nodeList,
                                    Source = "SourceID",
                                    Target = "TargetID",
                                    Value = "Weight",
                                    NodeID = "nName",
                                   units = "TWh", 
                                   fontSize = 12, 
                                   nodeWidth = 30)
  
  networkD3::saveNetwork(d3.sankeynetwork, 
                         paste(armDataVisualizations, paste(type, '_d3-sankey-network.html', sep = ''), sep = '/'), 
                         selfcontained = TRUE)
}


##### Plot Rules
################## Ebola ##################
rules.ebola <- arules::apriori(
  trans, 
  parameter = list(supp = 0.04,
                   conf = 0.8,
                   maxlen = 2,
                   minlen = 2))
rules.ebola <- subset(rules.ebola, subset = lift > 5)
rules.ebola <- rules.ebola[!is.redundant(rules.ebola)]
rules.ebola <- rules.ebola[!is.significant(rules.ebola, 
                                          trans, 
                                          method = "fisher", 
                                          adjust = 'bonferroni')]
# Attempt to focus attention on key words
(filtered.rules.ebola <- subset(rules.ebola, subset = 
                            (rhs %pin% 'ebola') | (rhs %pin% 'food') | (rhs %pin% 'security') | (rhs %pin% 'nutrition') | (rhs %pin% 'stability') | (rhs %pin% 'utilization') |
                            (lhs %pin% 'ebola') | (lhs %pin% 'food') | (lhs %pin% 'security') | (lhs %pin% 'nutrition') | (lhs %pin% 'stability') | (lhs %pin% 'utilization')
))
inspect(filtered.rules.ebola)

plotRules(filtered.rules.ebola, 'ebola')

################## Covid ##################
rules.covid <- arules::apriori(
  trans, 
  parameter = list(supp = 0.05,
                   conf = 0.8,
                   maxlen = 2,
                   minlen = 2))
rules.covid <- subset(rules.covid, subset = lift > 2)
rules.covid <- rules.covid[!is.redundant(rules.covid)]
rules.covid <- rules.covid[!is.significant(rules.covid, 
                                           trans, 
                                           method = "fisher", 
                                           adjust = 'bonferroni')]
# Attempt to focus attention on key words
(filtered.rules.covid <- subset(rules.covid, subset = 
                                  (rhs %pin% 'covid') | (rhs %pin% 'food') | (rhs %pin% 'security') | (rhs %pin% 'nutrition') | (rhs %pin% 'stability') | (rhs %pin% 'utilization') |
                                  (lhs %pin% 'covid') | (lhs %pin% 'food') | (lhs %pin% 'security') | (lhs %pin% 'nutrition') | (lhs %pin% 'stability') | (lhs %pin% 'utilization')
))
inspect(filtered.rules.covid)

plotRules(filtered.rules.covid, 'covid')

################## Locust ##################
rules.locust <- arules::apriori(
  trans, 
  parameter = list(supp = 0.05,
                   conf = 0.8,
                   maxlen = 2,
                   minlen = 2))
rules.locust <- subset(rules.locust, subset = lift > 2)
rules.locust <- rules.locust[!is.redundant(rules.locust)]
rules.locust <- rules.locust[!is.significant(rules.locust, 
                                           trans, 
                                           method = "fisher", 
                                           adjust = 'bonferroni')]
# Attempt to focus attention on key words
(filtered.rules.locust <- subset(rules.locust, subset = 
                                  (rhs %pin% 'locust') | (rhs %pin% 'food') | (rhs %pin% 'security') | (rhs %pin% 'nutrition') | (rhs %pin% 'stability') | (rhs %pin% 'utilization') |
                                  (lhs %pin% 'locust') | (lhs %pin% 'food') | (lhs %pin% 'security') | (lhs %pin% 'nutrition') | (lhs %pin% 'stability') | (lhs %pin% 'utilization')
))
inspect(filtered.rules.locust)

plotRules(filtered.rules.locust, 'locust')

################## Drought ##################
rules.drought <- arules::apriori(
  trans, 
  parameter = list(supp = 0.05,
                   conf = 0.8,
                   maxlen = 2,
                   minlen = 2))
rules.drought <- subset(rules.drought, subset = lift > 2)
rules.drought <- rules.drought[!is.redundant(rules.drought)]
rules.drought <- rules.drought[!is.significant(rules.drought, 
                                             trans, 
                                             method = "fisher", 
                                             adjust = 'bonferroni')]
# Attempt to focus attention on key words
(filtered.rules.drought <- subset(rules.drought, subset = 
                                   (rhs %pin% 'drought') | (rhs %pin% 'food') | (rhs %pin% 'security') | (rhs %pin% 'nutrition') | (rhs %pin% 'stability') | (rhs %pin% 'utilization')  |
                                   (lhs %pin% 'drought') | (lhs %pin% 'food') | (lhs %pin% 'security') | (lhs %pin% 'nutrition') | (lhs %pin% 'stability') | (lhs %pin% 'utilization')
))
inspect(filtered.rules.drought)

plotRules(filtered.rules.drought, 'drought')



#' Stores a file in S3
#'  
#' @param file A file
#' @param suffix The type of data. Used to strip from the filename for cleaning purposes
#' @param directory The inner directory used to store the data in S3
storeDataInS3 <- function(file) {
  print('Storing file in s3')
  print(file)
  put_object(file = file, object = file, bucket = 'datastore.portfolio.sampastoriza.com')
  print('Uploaded file to S3 successfully')
}

allFiles <- list.files(armDataPath, full.names = TRUE, pattern = '*')
print('Uploading arm data to S3')
lapply(allFiles, FUN = function(f) { storeDataInS3(f) })
allFiles <- list.files(armDataVisualizations, full.names = TRUE, pattern = '*', recursive = TRUE)
print('Uploading arm data visualizations to S3')
lapply(allFiles, FUN = function(f) { storeDataInS3(f) })

