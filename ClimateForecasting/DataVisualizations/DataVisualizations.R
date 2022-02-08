# ------------------Libraries------------------
if (!require("pacman")) {
  install.packages("pacman")
}

pacman::p_load(tidyverse, gridExtra) 
# ---------------------------------------------

# Visualize the weather/flood/wildfire data