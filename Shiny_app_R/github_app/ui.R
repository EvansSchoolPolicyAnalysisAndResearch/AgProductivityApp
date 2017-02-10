#this code will install packages only if they are not already installed 
{if (!require("devtools"))
  install.packages("devtools")
  if (!require("shiny")) 
    install.packages("shiny")
  if (!require("ggplot2")) 
    install.packages("ggplot2")
  if (!require("foreign")) 
    install.packages("foreign")
  if (!require("dplyr")) 
    install.packages("dplyr")
  if (!require("lazyeval")) 
    install.packages("lazyeval")
  if (!require("psych")) 
    install.packages("psych")
  if (!require("shinythemes")) 
    install.packages("shinythemes")}

#variable lists: matching names with labels. If you skip this step, your variable names will appear as-is in the dropdowns. 
categoricals <- {c("none" = "none", "year" = "year", "female-headed household " = "female_hoh_" , "household sold maize " = "sold_maize_" , 
                  "farm size category, <=2 ha (1), >2-4 ha (2), >4-10 ha (3), >10 ha (4)" = "smallholder_cat_" ,  
                  "household grew any fruit crops " = "grew_fruit_" ,  "household grew any permanent crops " = "grew_perm_" ,  "household grew annual crops " = "grew_annual_" ,  
                  "household increased maize yield between 2008 and 2010 " = "maize_increaser_2008_2010" , "household irrigated any plot " = "plot_irrigated_" ,  
                  "household used organic fertilizer on any plot " = "org_fert_" ,  "household used inorganic fertilizer on any plot " = "inorg_fert_" ,  
                  "household used pesticides or herbicides on any plot " = "pest_herb_usage_" ,  "household had any intercropped plot, any crop " = "landuse_ic_ap_") }


continuous <- {c("total farm area measure, ha - GPS-based if available, farmer-report if not " = "farmsize_ha_" ,  "maize area planted, by household " = "arpl_crop_" ,  
    "maize area harvested, by household " = "arhv_crop_" , "maize quantity harvested, by household " = "harv_quant_kg_" , 
    "maize yield by area harvested kg/ha (GPS) (harv_quant/area_harvested_ha)  " = "yield_arhv_ha_" ,  " maize yield by area planted kg/ha (GPS) (harv_quant/area_planted_ha)" = "yield_arpl_ha_" , 
    "change in maize yield by area harvested from 2008-2010 " = "yield_change_arhv_2008_2010" ,  "change in maize yield by area harvested from 2010-2012 " = "yield_change_arhv_2010_2012" ,  
    "change in maize yield by area planted from 2008-2010 " = "yield_change_arpl_2008_2010" , "change in maize yield by area planted from 2010-2012 " = "yield_change_arpl_2010_2012" ,
    
    "total number of household labor days on farm " = "tot_hh_labor_days_" ,  "total number of hired labor days " = "tot_hired_labor_days_" ,  "quantity of maize sold, kg " = "quant_sold_" ,  
    "maize price clustered median (smallest geo unit w/ >=10 price values) " = "shadowpricecluster_lrs_" ,
    "number of household members " = "hh_size_" ,  "distance to nearest trunk road (as defined by TANROADS) (geovars) " = "dist_road_" ,  
    "distance to nearest major market (FEWSNET key market centers) (geovars) " = "dist_market_" ,  "age of head of household " = "age_hoh_" ,  "years of education completed by the household head " = "educ_yrs_hoh_" ,  
     
    "total land allocation to annual crops besides maize " = "alloc_otherann_" ,  "total land allocation to permanent/fruit crops " = "alloc_perm_" ,  
    "change in land allocation to maize, 2010-2012 " = "alloc_change_maize_2010_2012" ,  
    "change in land allocation to annual crops besides maize, 2010-2012 " = "alloc_change_otherann_2010_2012" ,  "change in land allocation to permanent/fruit crops, 2010-2012 " = "alloc_change_perm_2010_2012" ,  
    "change in land allocation to maize, 2008-2010 " = "alloc_change_maize_2008_2010" ,  "change in land allocation to annual crops besides maize, 2008-2010 " = "alloc_change_otherann_2008_2010" ,  
    "change in land allocation to permanent/fruit crops, 2008-2010 " = "alloc_change_perm_2008_2010"   
    )}

allvarlist <- {c("none" = "none", "year" = "year", "female-headed household " = "female_hoh_" , "household sold maize " = "sold_maize_" , 
                 "farm size category, <=2 ha (1), >2-4 ha (2), >4-10 ha (3), >10 ha (4)" = "smallholder_cat_" ,  
                 "household grew any fruit crops " = "grew_fruit_" ,  "household grew any permanent crops " = "grew_perm_" ,  "household grew annual crops " = "grew_annual_" ,  
                 "household increased maize yield between 2008 and 2010 " = "maize_increaser_2008_2010" ,   "household irrigated any plot " = "plot_irrigated_" ,  
                 "household used organic fertilizer on any plot " = "org_fert_" ,  "household used inorganic fertilizer on any plot " = "inorg_fert_" ,  
                 "household used pesticides or herbicides on any plot " = "pest_herb_usage_" ,  "household had any intercropped plot, any crop " = "landuse_ic_ap_", 
                #continuous
                "total farm area measure, ha - GPS-based if available, farmer-report if not " = "farmsize_ha_" ,  "maize area planted, by household " = "arpl_crop_" ,  
                "maize area harvested, by household " = "arhv_crop_" , "maize quantity harvested, by household " = "harv_quant_kg_" , 
                "maize yield by area harvested kg/ha (GPS) (harv_quant/area_harvested_ha)  " = "yield_arhv_ha_" ,  " maize yield by area planted kg/ha (GPS) (harv_quant/area_planted_ha)" = "yield_arpl_ha_" ,  
                "change in maize yield by area harvested from 2008-2010 " = "yield_change_arhv_2008_2010" ,  "change in maize yield by area harvested from 2010-2012 " = "yield_change_arhv_2010_2012" ,  
                "change in maize yield by area planted from 2008-2010 " = "yield_change_arpl_2008_2010" , "change in maize yield by area planted from 2010-2012 " = "yield_change_arpl_2010_2012" ,
                
                "total number of household labor days on farm " = "tot_hh_labor_days_" ,  "total number of hired labor days " = "tot_hired_labor_days_" ,  "quantity of maize sold, kg " = "quant_sold_" ,  
                "maize price clustered median (smallest geo unit w/ >=10 price values) " = "shadowpricecluster_lrs_" ,
                "number of household members " = "hh_size_" ,  "distance to nearest trunk road (as defined by TANROADS) (geovars) " = "dist_road_" ,  
                "distance to nearest major market (FEWSNET key market centers) (geovars) " = "dist_market_" ,  "age of head of household " = "age_hoh_" ,  "years of education completed by the household head " = "educ_yrs_hoh_" ,  
                
                "total land allocation to annual crops besides maize " = "alloc_otherann_" ,  "total land allocation to permanent/fruit crops " = "alloc_perm_" ,  
                "change in land allocation to maize, 2010-2012 " = "alloc_change_maize_2010_2012" ,  
                "change in land allocation to annual crops besides maize, 2010-2012 " = "alloc_change_otherann_2010_2012" ,  "change in land allocation to permanent/fruit crops, 2010-2012 " = "alloc_change_perm_2010_2012" ,  
                "change in land allocation to maize, 2008-2010 " = "alloc_change_maize_2008_2010" ,  "change in land allocation to annual crops besides maize, 2008-2010 " = "alloc_change_otherann_2008_2010" ,  
                "change in land allocation to permanent/fruit crops, 2008-2010 " = "alloc_change_perm_2008_2010")}

#this is a version with no "none" option
allvarlist2 <- {c("year" = "year", "female-headed household " = "female_hoh_" , "household sold maize " = "sold_maize_" , 
                 "farm size category, <=2 ha (1), >2-4 ha (2), >4-10 ha (3), >10 ha (4)" = "smallholder_cat_" ,  
                 "household grew any fruit crops " = "grew_fruit_" ,  "household grew any permanent crops " = "grew_perm_" ,  "household grew annual crops " = "grew_annual_" ,  
                 "household increased maize yield between 2008 and 2010 " = "maize_increaser_2008_2010" ,   "household irrigated any plot " = "plot_irrigated_" ,  
                 "household used organic fertilizer on any plot " = "org_fert_" ,  "household used inorganic fertilizer on any plot " = "inorg_fert_" ,  
                 "household used pesticides or herbicides on any plot " = "pest_herb_usage_" ,  "household had any intercropped plot, any crop " = "landuse_ic_ap_", 
                 #continuous
                 "total farm area measure, ha - GPS-based if available, farmer-report if not " = "farmsize_ha_" ,  "maize area planted, by household " = "arpl_crop_" ,  
                 "maize area harvested, by household " = "arhv_crop_" , "maize quantity harvested, by household " = "harv_quant_kg_" , 
                 "(harv_quant/area_harvested_ha) maize yield by area harvested kg/ha (GPS) " = "yield_arhv_ha_" ,  "(harv_quant/area_planted_ha) maize yield by area planted kg/ha (GPS) " = "yield_arpl_ha_" , 
                 "change in maize yield by area harvested from 2008-2010 " = "yield_change_arhv_2008_2010" ,  "change in maize yield by area harvested from 2010-2012 " = "yield_change_arhv_2010_2012" ,  
                 "change in maize yield by area planted from 2008-2010 " = "yield_change_arpl_2008_2010" , "change in maize yield by area planted from 2010-2012 " = "yield_change_arpl_2010_2012" ,
                 
                 "total number of household labor days on farm " = "tot_hh_labor_days_" ,  "total number of hired labor days " = "tot_hired_labor_days_" ,  "quantity of maize sold, kg " = "quant_sold_" ,  
                 "distance household transported maize to sale, km " = "dist_transported_avg_" ,  "maize price clustered median (smallest geo unit w/ >=10 price values) " = "shadowpricecluster_lrs_" ,
                 "number of household members " = "hh_size_" ,  "distance to nearest trunk road (as defined by TANROADS) (geovars) " = "dist_road_" ,  
                 "distance to nearest major market (FEWSNET key market centers) (geovars) " = "dist_market_" ,  "age of head of household " = "age_hoh_" ,  "years of education completed by the household head " = "educ_yrs_hoh_" ,  
                 
                 "total land allocation to annual crops besides maize " = "alloc_otherann_" ,  "total land allocation to permanent/fruit crops " = "alloc_perm_" ,  
                 "change in land allocation to maize, 2010-2012 " = "alloc_change_maize_2010_2012" ,  
                 "change in land allocation to annual crops besides maize, 2010-2012 " = "alloc_change_otherann_2010_2012" ,  "change in land allocation to permanent/fruit crops, 2010-2012 " = "alloc_change_perm_2010_2012" ,  
                 "change in land allocation to maize, 2008-2010 " = "alloc_change_maize_2008_2010" ,  "change in land allocation to annual crops besides maize, 2008-2010 " = "alloc_change_otherann_2008_2010" ,  
                 "change in land allocation to permanent/fruit crops, 2008-2010 " = "alloc_change_perm_2008_2010")}

library(shinythemes)

#set up the user interface
shinyUI(fluidPage(theme = shinytheme("cosmo"), #choose a theme
  headerPanel("Maize Yield and Land Allocation by Tanzanian Farmers (Tanzania National Panel Survey 2008-2012)"), #title
  
  sidebarPanel( #this will be in the left side panel - all user inputs and notes
    
    h3("Scatterplot"), #title - heading level 3
    h5("each dot represents one household"),
    #drop-down inputs
    selectInput('x', 'Scatterplot X Variable', choices = c(allvarlist), selected= "arpl_crop_"),
    selectInput('y', 'Scatterplot Y Variable', choices = c(allvarlist), selected = "harv_quant_kg_"),
    selectInput('color', 'Scatterplot Color Variable', c('none', allvarlist2)),
    h6("note: if binary variable is selected, scale will look continuous, but colors will be 1 or 0"), 
    
    selectInput('facet_row', 'Scatterplot Facet Row', choices = c(categoricals), selected = "none"), 
    selectInput('facet_col', 'Scatterplot Facet Column', choices = c(categoricals), selected = "year"),

    h4("Scatterplot Options"),
    checkboxInput('jitter', 'Jitter (spread out the points for a categorical variable)'),
    checkboxInput('smooth', 'Smooth (add a loess smoother line and confidence interval)'),
  
  h3("Histogram & Summary Statistics"),
  selectInput('hist', 'Histogram Variable', choices = c(continuous), selected = "farmsize_ha_"),
  numericInput('n_breaks', 'Histogram Bin Width (type a number, based on axis scale)', value = 50),
  numericInput('bottom', 'Histogram Lower Limit Percentile (type a number between 0 and 1, 
               .01 = exclude bottom 1% of pooled-wave sample)', value = 0), #default no bottom trim
  numericInput('top', 'Histogram Upper Limit Percentile', value = 1), #default no top trim
  selectInput('facet_row2', 'Histogram Facet Row (group1)', choices = c(categoricals), selected = "none"), 
  selectInput('facet_col2', 'Histogram Facet Column (group2)', choices = c(categoricals), selected = "year"),
  
  helpText("Data from Tanzania National Panel Survey (Living Standards Measurement Study - Integrated Surveys on Agriculture). App developed by Evans School Policy Analysis & Research Group, University of Washington, 2016.") #caption at bottom
  ),
  
  mainPanel( #this will be in the main body of the page - make placeholder spots for the charts
    fluidRow( #fluidrow will adjust to page size
           h4("Drag a rectangle to zoom: this plot"),
           fluidRow(
             #make a plot where you can drag a rectangle, which will make the next plot down zoom
                    plotOutput("plot2",
                               brush = brushOpts(
                                 id = "plot2_brush",
                                 resetOnNew = TRUE
                               )
                    )
             ),
           #this plot will zoom based on the rectangle you draw
           h4("controls the zoom of this plot (changing options will reset)"),
             plotOutput("plot3")
             ),

    fluidRow(
    plotOutput("histplot"))), #simple histogram
  
 fluidRow( #this is outside the main panel, its own row across the bottom
    h4(" Unweighted Summary Statistics for Histogram Variable (grouped by year, and by histogram facet row if selected)"),
    verbatimTextOutput("summary"), #output summary statistics below
    h5(" statistics provided: 
      item name, item number, grouping variable levels, number of valid cases, mean, standard deviation, trimmed mean (with trim defaulting to .1), 
       median (standard or interpolated), mad: median absolute deviation (from the median), minimum, 
       maximum, range, skew, kurtosis, standard error, 1st, 2nd, 25th, 50th, 75th, 98th, 99th percentile values")
  )
 ))