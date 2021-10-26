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
library(tkplot)

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
processedPdfData <- '../PandemicComparison/processed_data/cleaned_corpus_data.csv'

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
rules <- subset(rules, subset = lift > 3)
rules <- rules[!is.redundant(rules)]
rules <- rules[!is.significant(rules, 
                              trans, 
                              method = "fisher", 
                              adjust = 'bonferroni')]
# Attempt to focus attention on key words
(filtered.rules <- subset(rules, subset = (rhs %pin% 'covid') | (rhs %pin% 'food') | (rhs %pin% 'drought') | (rhs %pin% 'security') | (rhs %pin% 'utilization') | (rhs %pin% 'stability') | (rhs %pin% 'malnutrition') | (rhs %pin% 'ebola') | (rhs %pin% 'locust') |
                                          (lhs %pin% 'covid') | (lhs %pin% 'food') | (lhs %pin% 'drought') | (lhs %pin% 'security') | (lhs %pin% 'utilization') | (lhs %pin% 'stability') | (lhs %pin% 'malnutrition') | (lhs %pin% 'ebola') | (lhs %pin% 'locust')
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

### Plot graph of rules by lift, confidence, and support
subrules <- head(rules, n = 500, by = "lift")
p <- plot(subrules, engine = "plotly")
htmlwidgets::saveWidget(as_widget(p), paste(armDataVisualizations, 'rules_lcs.html', sep = '/'))
######################

### Plot network of rules using visNetwork
p.v <- plot(rules, method = "graph", engine = "visNetwork")
htmlwidgets::saveWidget(as_widget(p.v), paste(armDataVisualizations, 'rules_viz_network.html', sep = '/'))
######################

### Begin process of transformation for network d3
df.2 <- DATAFRAME(rules, setStart = '', setEnd = '', separate = TRUE)

## Convert to char
df.2$LHS <- as.character(df.2$LHS)
df.2$RHS <- as.character(df.2$RHS)

rules.clean <- df.2[c(1,2,6)]
names(rules.clean) <- c("SourceName", "TargetName", "Weight")
edgeList <- rules.clean
(graph.rules <- igraph::simplify(igraph::graph.data.frame(edgeList, directed = TRUE)))

### Plot network of rules using tkplot
plot(igraph::graph.data.frame(edgeList, directed = TRUE), engine = 'htmlwidget')
graph.layout <- layout.kamada.kawai(graph.rules)
tkplot(graph.rules, edge.arrow.size = 0.3,
       vertex.color="lightblue",
       layout=graph.layout,
       edge.arrow.size=.5,
       vertex.label.cex=0.8, 
       vertex.label.dist=2, 
       edge.curved=0.2,
       vertex.label.color="black",
       edge.weight=5, 
       rescale = TRUE, 
       ylim=c(0,40),
       xlim=c(0,40)
)

## Build Node and Edge List
nodeList <- data.frame(ID = c(0:(igraph::vcount(graph.rules) - 1)), 
                       nName = igraph::V(graph.rules)$name)

(nodeList <- cbind(nodeList, nodeDegree=igraph::degree(graph.rules, 
                                                       v = igraph::V(graph.rules), mode = "all")))


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

d3.network <- networkD3::forceNetwork(
  Links = edgeList,
  Nodes = nodeList,
  Source = "SourceID",
  Target = "TargetID",
  Value = "Weight",
  NodeID = "nName",
  Group = "nodeDegree",
  opacity = 0.8,
  zoom = TRUE,
) 

networkD3::saveNetwork(d3.network, 
                       paste(armDataVisualizations, 'd3-network.html', sep = '/'), 
                       selfcontained = TRUE)
######################

### Build Sankey Network
d3.sankeynetwork  <- sankeyNetwork(Links = edgeList,
                                  Nodes = nodeList,
                                  Source = "SourceID",
                                  Target = "TargetID",
                                  Value = "Weight",
                                  NodeID = "nName",,
                                 units = "TWh", 
                                 fontSize = 12, 
                                 nodeWidth = 30)

networkD3::saveNetwork(d3.sankeynetwork, 
                       paste(armDataVisualizations, 'd3-sankey-network.html', sep = '/'), 
                       selfcontained = TRUE)

