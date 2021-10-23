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

library(arules)
library(arulesViz)
library(plotly)