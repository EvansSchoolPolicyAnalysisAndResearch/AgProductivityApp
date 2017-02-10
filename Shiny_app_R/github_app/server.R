
#set working directory 
#setwd("FILEPATH") #fill in path to app folder here with only / slashes, and uncomment line

#this code will install packages only if they are not already installed - this will take a few moments the first time it's run
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

#load libraries 
library(ggplot2) #make plots
library(foreign) #read foreign files like .dta
library(dplyr) #lots of functions, use piping
library(lazyeval) #running in the background of dplyr
library(psych) #to use describeBy
library(shiny) #need Shiny 
library(shinythemes) #to customize themes

#read in the data
yieldsraw <- read.dta("data/shiny_data.dta") #we have a .dta file from Stata, but this could be any type of data file that R or Foreign can read
yieldsframe <- as.data.frame(yieldsraw) #make it a data frame
yields <- mutate_(yieldsframe, none="1") #workaround: make a variable with only one level as the default grouping var (because descriptive statistics weren't reacting when there was no group var)

#now the server function - all the outputs will be defined here
shinyServer(function(input, output) {
  
  ranges2 <- reactiveValues(x = NULL, y = NULL) #make an object for the scatterplot to recognize if it should zoom in
  
#output for scatterplots
  output$plot2 <- renderPlot({
    
    p <- ggplot(yields, aes_string(x=input$x, y=input$y)) + theme_bw() + geom_point(pch=1) #make a plot called p based on the chosen input variables 
    
    if (input$color != 'none') #react if color input is chosen
      p <- p + aes_string(color=input$color) #note: this isn't recognizing categorical color schemes (works for continuous and binary)
    
    facets <- paste(input$facet_row, '~', input$facet_col) #make an object showing if facets have been chosen
    if (facets != '. ~ .') #react if a facet is chosen
      p <- p + facet_grid(facets) 
    
    if (input$jitter) #react if jittering is selected
      p <- p + geom_jitter(pch=1) #set the points to be open circles
    if (input$smooth) #react if smoothing is selected
      p <- p + geom_smooth(method = loess, col="coral1") #default is loess below n=1000 and GAM above n=1000, set to always loess
    p <- p + theme(text = element_text(size = 14))
    p #print it
  })
  
  output$plot3 <- renderPlot({
    o <- ggplot(yields, aes_string(x=input$x, y=input$y)) + theme_bw() + geom_point(pch=1) +
      coord_cartesian(xlim = ranges2$x, ylim = ranges2$y, expand = FALSE)      #make ranges react to brushing on above plot
    #this repeats above commands
    if (input$color != 'none')
      o <- o + aes_string(color=input$color) 
    
    facets <- paste(input$facet_row, '~', input$facet_col)
    if (facets != '. ~ .')
      o <- o + facet_grid(facets) 
    
    if (input$jitter)
      o <- o + geom_jitter(pch=1)
    if (input$smooth)
      o <- o + geom_smooth(col="coral1")
    
    o <- o + coord_cartesian(xlim = ranges2$x, ylim = ranges2$y, expand = FALSE) #make ranges react to brushing on above plot - was causing a problem if this wasn't at the bottom
    o <- o + theme(text = element_text(size = 14))
    o #do NOT use "print(o)" instead here, the scaling will be wrong on the zoomed chart
  })
  
  #this code makes it so dragging a rectangle on the top scatterplot will reset the zoom on the bottom scatterplot  
  observe({       #reactive
    brush <- input$plot2_brush #make an object that will check if a brush square has been dragged
    if (!is.null(brush)) {
      ranges2$x <- c(brush$xmin, brush$xmax)
      ranges2$y <- c(brush$ymin, brush$ymax)
      
    } else {
      ranges2$x <- NULL
      ranges2$y <- NULL
    }
  })
  
  #output for histogram 
  output$histplot <- renderPlot({
    #set aesthetics, set bins to be controlled by numeric input
    q <- ggplot(yields, aes_string(input$hist)) + geom_histogram(binwidth = (as.numeric(input$n_breaks)), col= "dodgerblue4", fill="dodgerblue", alpha = .7) + 
      theme_bw() 
    
    #input$hist as an object is a character vector, so we have to call it together with its source to call the chosen variable itself and not just its name
    numvar <- yields[, input$hist] 
    
    #make objects based on percentiles to trim the histogram you see
    upper.cut <- quantile(numvar, probs = input$top, na.rm = TRUE)
    lower.cut <- quantile(numvar, probs = input$bottom, na.rm = TRUE)  
    
    facets2 <- paste(input$facet_row2, '~', input$facet_col2) #adjust to facets
    if (facets2 != '. ~ .')
      q <- q + facet_grid(facets2)
    q <- q + coord_cartesian(xlim = c(lower.cut, upper.cut)) 
    q <- q + theme(text = element_text(size = 14))
    q    
  })
 
  #output for summary stats
  # use a reactive value to represent grouping variable selection for descriptives
  group_selects <- reactiveValues(value = NULL) #make a reactive object
  observe({
    input$facet_row2
    if(is.null(input$facet_row2) || input$facet_row2 == '')
      group_selects$value <- NULL  #this doesn't seem to be working - thus did workaround of making variable named "none" that always has value of 1
    else {
      group_selects$value <- unique(yields[[input$facet_row2]])
    }
  })
  
  data_to_plot <- reactive({
    if(!(is.null(input$facet_row2) || input$facet_row2 == '')) {
      req(group_selects$value)                        # To prevent unnecessary re-run
      dataset <- as.data.frame(yields) %>% #take a data frame of the data
        mutate_(group_ = input$facet_row2) %>% #make a new var called group_ that is equal to the selected facet row
        select_(input$hist, "group_", "year") #keep only the histogram variable, group_, and year - note this is the only place (and in next block of code) where a variable is hard-coded (needs to be changed to work with new data)

    } else {
      dataset<- as.data.frame(yields) %>% 
        mutate_(group_ = "1") %>%  #if nothing is chosen, make group_ equal to 1 - this part doesn't seem to work, using variable "none" instead
        select_(input$hist, "group_", "year")
    }
    return(dataset)
  })

output$summary <- renderPrint({
 dataset <- data_to_plot()
  validate(
    need(!(is.null(dataset) || nrow(dataset) == 0), #make sure there is data 
         'There are no data to plot!')
  )
  

  v <- describeBy(dataset, list(dataset$group_, dataset$year), quant=c(.01, .02, .25, .5, .75, .98, .99), mat=TRUE, digits=1) #use describeBy from psych package to show all summary stats. If switching to another dataset will need to change reference to "year" variable in this line.  
  #added "quant()" option from describe command to get additional percentiles. This may be more customizable - would like to not output the stats for the grouping variables in the matrix.
  v

  
  
})
})
