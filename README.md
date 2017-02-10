# AgProductivityApp
R Shiny app visualizing data from the Tanzania National Panel Survey. 

This repository provides server and UI files to run the app (https://evans.uw.edu/policy-impact/epar/agricultural-productivity-tanzania) locally or for modification for other similar uses (in the Shiny_app_R folder). 
To run the app locally, open both the server.R and ui.R files in RStudio, change the directory filepath, and then click "run app". 
Learn more about Shiny here: https://shiny.rstudio.com/


Cleaning and variable derivation files are also provided to replicate the dataset creation in Stata. 
To recreate the dataset, you will need to download Tanzania raw data from the World Bank for all three waves. This includes signing a use agreement. 
Links to download each wave are here: http://econ.worldbank.org/WBSITE/EXTERNAL/EXTDEC/EXTRESEARCH/EXTLSMS/0,,contentMDK:23635522~pagePK:64168445~piPK:64168309~theSitePK:3358997,00.html
After downloading the data, the .do files are to be run in this order: 
1. W1_Ag_merge.do
2. W2_Ag_merge.do
3. W3_Ag_merge.do
4. W1-3_Cluster_Prices.do
5. Three-panel_merge.do : this file will output the input data for the R Shiny app. 


If you use or modify our app, or adapt it to your own data, please cite us using the provided citation and DOI. 
