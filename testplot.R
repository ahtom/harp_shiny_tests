library("roxygen2")
roxygen2::roxygenize("harpVis-develop", roclets = c('rd', 'collate', 'namespace'))
library("harpVis")
library("tidyverse")
library("dplyr")
library("RSQLite")
library("DT")
library("DBI")

harpVis::shiny_plot_spatial_verif()
