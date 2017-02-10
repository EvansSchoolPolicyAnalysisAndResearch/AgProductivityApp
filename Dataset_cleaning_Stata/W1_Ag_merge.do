********************************************************************************************************
*Title/Purpose of Do File: Tanzania LSMS-ISA W1(2008) - Ag survey - Prepare data for Shiny agricultural productivity app
*Unique identifiers (level): hhid zaocode
*Author(s): Katie Panhorst Harris, Maggie Beetstra
*Date started: 11/27/15
*Date completed: 8/8/16

*Checked by: David Coomes	
*Date: 1/9/17
********************************************************************************************************

*This file to be run before Three-panel_merge and W1-3_Cluster_Prices

/* INSPECTING AG DATA FOR MERGES

HIERARCHY: 
hhid (household ID Y1)
	plotnum (Plot Number)
		zaocode (crop code)

		
////////SKIP (for this analysis, we are not interested in any individual level variables, any data on livestock or fisheries, or network information)
SEC_1_ALL - individual roster (individual level)

Short Rainy Season - not needed for this analysis
SEC_2B
SEC_3B
SEC_4B
SEC_5B
SEC_6B
SEC_7B

Outgrower schemes/contract farming (hh-crop level) - only 16, 12, 1 observation - can't do anything with this sample size
SEC_8A
SEC_8B
SEC_8C
**Unique ID: hhid zaocode


//SKIP, NEEDS TO BE COLLAPSED IF USED - these files are at a different observation level and need to be collapsed to the plot or household level. 
See .do file: 
Livestock and Fisheries
SEC_10A
SEC_10B
SEC_12_A-D 

Network Roster
SEC_NETWORK

Processed ag products and biproducts (crop-product level)
*SKIP - we would need to know what biproducts we are interested in to collapse this file for analysis.
SEC_9_ALL

Farm Implements and Machinery (implement level)
SEC_11_ALL

Extension (source level)
SEC_13A
SEC_13B

Shocks - HH data


////////READY TO MERGE - these files will merge at the plot-crop level, then will need to be collapsed to household-crop level.
Filter questions: start with this (hh level)
SEC_QNFLOW
**Unique ID: hhid

Plot Roster (plot level)
SEC_2A
**Unique ID: hhid plotnum

Plot Details (plot level)
SEC_3A
**Unique ID: hhid plotnum

Annual crops by plot (plot-crop level)
SEC_4A
**Unique ID: hhid plotnum zaocode

Permanent crops by plot (plot-crop level)
SEC_6A
**Unique ID: hhid plotnum zaocode

////////These already at household-crop level
Annual crop production and sales (hh-crop level)
SEC_5A
**Unique ID: hhid zaocode

Permanent crop production and sales (hh-crop level)
SEC_7A
**Unique ID: hhid zaocode

*/


//SET DIRECTORIES - make sure to reset these
clear
global input "FILEPATH" //where the agricultural module is downloaded, reset
global input2 "FILEPATH" //where the household module is downloaded, reset
global output "FILEPATH\Merged Data Shiny" //set up an output folder to save .dtas to use in the panel merge, reset 
global collapse "FILEPATH\Collapse Data Shiny" //set up an output folder for collapsed .dtas, reset 

///////////////////////////////////////////////
///											///
///					COLLAPSING				///
///											///
///////////////////////////////////////////////


************************************************
//////MAIZE OWN-CONSUMPTION: HH Data SEC K//////
************************************************
**data is presented at the item level, we will need to collapse it to the household level. 
**the only product we care about is maize, item codes 0103, 0104, and 0105, that comes from own production, question 5. 
**also preserve total quantity consumed in case we want to use proportion of the total that came from own production. 
clear
use "$input2\SEC_K1"


**Generating variables
gen cons_tot_greenmaize_kg =.
replace cons_tot_greenmaize_kg = skq2_amount if skq2_meas == 1 & skcode == 0103
replace cons_tot_greenmaize_kg = skq2_amount/1000 if skq2_meas == 2 & skcode == 0103
replace cons_tot_greenmaize_kg = 0 if skq1 == 2 & skcode ==0103

gen cons_tot_maizegrain_kg =.
replace cons_tot_maizegrain_kg = skq2_amount if skq2_meas == 1 & skcode == 0104
replace cons_tot_maizegrain_kg = skq2_amount/1000 if skq2_meas == 2 & skcode == 0104
replace cons_tot_maizegrain_kg = 0 if skq1 == 2 & skcode ==0104

gen cons_tot_maizeflour_kg =.
replace cons_tot_maizeflour_kg = skq2_amount if skq2_meas == 1 & skcode == 0105
replace cons_tot_maizeflour_kg = skq2_amount/1000 if skq2_meas == 2 & skcode == 0105
replace cons_tot_maizeflour_kg = 0 if skq1 == 2 & skcode ==0105

gen cons_own_greenmaize_kg =0
replace cons_own_greenmaize_kg = skq5_amount if skq5_meas == 1 & skcode == 0103
replace cons_own_greenmaize_kg = skq5_amount/1000 if skq5_meas == 2 & skcode == 0103

gen cons_own_maizegrain_kg =0
replace cons_own_maizegrain_kg = skq5_amount if skq5_meas == 1 & skcode == 0104
replace cons_own_maizegrain_kg = skq5_amount/1000 if skq5_meas == 2 & skcode == 0104

gen cons_own_maizeflour_kg =0
replace cons_own_maizeflour_kg = skq5_amount if skq5_meas == 1 & skcode == 0105
replace cons_own_maizeflour_kg = skq5_amount/1000 if skq5_meas == 2 & skcode == 0105

////////////COLLAPSE TO HH LEVEL

local consumption cons_*
collapse (max) `consumption', by (hhid)

la var cons_tot_greenmaize_kg "(skq2) total household weekly consumption of green maize, kg"
la var cons_tot_maizegrain_kg "(skq2) total household weekly consumption of maize grain, kg"
la var cons_tot_maizeflour_kg "(skq2) total household weekly consumption of maize flour, kg"
la var cons_own_greenmaize_kg "(skq5) household weekly consumption from own production of green maize, kg"
la var cons_own_maizegrain_kg "(skq5) household weekly consumption from own production of maize grain, kg"
la var cons_own_maizeflour_kg "(skq5) household weekly consumption from own production of maize flour, kg"

save "$collapse/HH_SEC_K1_maize_consumption.dta", replace


************************************************
///////////HOUSEHOLD SECTION////////////////////
************************************************
*We only need to preserve a few variables from this section: age of HH head, education of HH head, gender of HH head
clear
use "$input2\SEC_A_T"

//Merge in section B: Household Member Roster
//Merge in section C: Education
**Unaltered .dta files
sort hhid
merge 1:m hhid using "$input2\SEC_B_C_D_E1_F_G1_U", generate (_merge_HH_SEC_B_C)
//matched: 16,709
//not matched:0

//Generate variable for HH size (note there is an "adult equivalent" hh size number in consumption file)
egen hh_size = count(sbmemno), by(hhid) 
la var hh_size "count (sbmemno): number of household members"

//Keep only the variables we need
keep hhid sbmemno sbq2 sbq4 sbq5 scq1 scq2 scq3 scq4 scq5 scq6 scq7 scq9 source clusterid strataid hh_weight hh_weight_trimmed ///
rural district ward locality ea hh_size
isid hhid sbmemno

//sbq5 identifies the HH head. Dropping others
drop if sbq5!=1
isid hhid
//n=3,265 HH

save "$collapse/HH_merge.dta", replace 



///////////////////////////////////////
//									 //
//		MERGE ALL DATA FILES 		 //
//									 //
///////////////////////////////////////



////////////Begin by merging all plot-crop level data together
clear
use "$input/SEC_4A.dta"
isid hhid plotnum zaocode, missok
drop if zaocode ==. //1 deleted
gen grew_annual = 1
la var grew_annual "hh grew annual crops in 2008 (answered section 4)"

/////////////////////////////////////////////////////////////////////


**Merge Fruit crops by plot (plot-crop level) 
merge 1:m hhid plotnum zaocode using "$input/SEC_6A", gen (_merge_SEC_6A)
**Unique ID: hhid plotnum zaocode
*21 matched (these farmers must have reported a permanent crop in the annual crop section by mistake)
*5682 not matched from master (these are the annual crops)
*3252 not matched from using (these are the permanent crops)

**add in 6B: other permanent crops
merge 1:1 hhid plotnum zaocode using "$input/SEC_6B.dta", gen (_merge_SEC_6B)
**87 matched (hh reported crop in both fruit AND permanent), 8868 not matched from master (annual and fruit), 2348 not matched from using (permanent)
isid hhid plotnum zaocode, missok

replace grew_annual = 0 if grew_annual ==.

save "$collapse\crop_level.dta", replace 


***************************************************************************************
************	PLOT LEVEL and PLOT-CROP LEVEL TO HH-CROP LEVEL	   ******************** 
***************************************************************************************

********** PLOT LEVEL DATA *************
//We will begin by merging the plot-level datasets and creating the plot-level variables we need. Afterwards we will merge the plot-crop sections and create the crop-level variables. 
//For this analysis, we will have to collapse to the crop-hh level to merge panels.

clear
use "$input/SEC_2A.dta"
*Unique ID: hhid plotnum
*Dataset is now at PLOT LEVEL (5128 obs)


**Plot Details (plot level)
merge 1:1 hhid plotnum using "$input/SEC_3A.dta", gen (_merge_SEC_3A)
*5126 matched, 2 not matched from master

**Crops by plot (plot-crop level) Sections 4A, 6A, 6B -- DATASET IS NOW AT CROP LEVEL
merge 1:m hhid plotnum using "$collapse/crop_level.dta", gen (_merge_crop_level)
*11271 matched, 628 not matched from master (non-cultivating), 32 not matched from using (mostly on SRS plots)

**Plot level geovars
merge m:1 hhid plotnum using "$input/Geovariables/Plot_Geovariables_Y1_revised2", gen (_merge_plotgeo)
**Unique ID: HHID Plotnum
*2262 matched, 9669 not matched from master, 13 not matched from using (lots of missing data)


//////////COLLAPSE THIS FILE TO THE HH-CROP LEVEL
//First generate the variables we will need
gen plot_cultivated =1 if s3aq36==1
replace plot_cultivated =0 if s3aq36==2
la var plot_cultivated "plot cultivated during LRS 2008 (s3aq36)"

**************Plot size************
gen plotsize_acres = s2aq4
la var plotsize_acres "(s2aq4) farmer reported plot size in acres"

gen plotsize_ha = plotsize_acres* 0.404685642
la var plotsize_acres "(s2aq4) farmer reported plot size in hectares"

gen plotsize_acres_gps = area
la var plotsize_acres_gps "(area) GPS measured plot size in acres"

gen plotsize_ha_gps = plotsize_acres_gps* 0.404685642
la var plotsize_ha_gps "(area) GPS measured plot size in hectares"

gen diff_gps_fr =.
replace diff_gps_fr = plotsize_ha_gps - plotsize_ha if plotsize_ha_gps !=. & plotsize_ha !=.
la var diff_gps_fr "GPS plotsize minus farmer reported plotsize"

** make the area measure we will use for yield and area calculations: GPS measure for HH that have it, FR if not 
gen plot_area = plotsize_ha
replace plot_area = plotsize_ha_gps if plotsize_ha_gps !=.
la var plot_area "plot area measure, ha - GPS-based if they have one, farmer-report if not"

*make a var identifying whether FR or GPS was used for this hh for this year
gen fr_hh = 0
replace fr_hh =1 if plotsize_ha_gps ==.
la var fr_hh "number of plots without a GPS measure (farmer-reported area used)"

*******MAKE "TOTAL LANDHOLDING" VAR
//create tag for the first plotnum by hhid so that we can sum plotsize in the next variables
egen plot_tag =tag(hhid plotnum) //step var only
la var plot_tag "plot-level tag"

//GPS-based if they have one, farmer-report if not
egen sum_plot_area = sum(plot_area) if plot_tag==1 & plot_area!=., by(hhid)
// the code below is needed so that the number of plots fills in by hhid (run piece by piece if unclear)
// in otherwords, egen above will create missings for duplicate plots and we want those missings to fill in with the value
// so that every plot has the sum of plotsizes (total landholding) at each level of the data
bysort hhid: egen totplot=max(sum_plot_area) 
replace sum_plot_area=totplot // tell it to back fill so that missings are changed to the number of plots
drop totplot // don't need it
la var sum_plot_area "sum(plot_area) sum of all HH plots in ha LRS 2012 - GPS-based if they have one, farmer-report if not"

**********************SOIL************************
//looking at soil type and soil quality
rename s3aq7 soil_type
label var soil_type "Soil type of the plot"
rename s3aq8 soil_quality
label var soil_quality "Soil quality of the plot"

*******************IRRIGATION*********************
gen plot_irrigated=.
replace plot_irrigated = 1 if s3aq15==1
replace plot_irrigated = 0 if s3aq15==2
label var plot_irrigated "Plot irrigated"

*******************FERTILIZER*********************
gen org_fert=.
replace org_fert = 1 if s3aq37==1
replace org_fert = 0 if s3aq37==2
label var org_fert "Organic fertilizer used on plot"

gen inorg_fert=.
replace inorg_fert = 1 if s3aq43==1
replace inorg_fert = 0 if s3aq43==2
label var inorg_fert "Inorganic fertilizer used on plot"

***************PESTICIDE/HERBICIDE****************
gen pest_herb_usage=.
replace pest_herb_usage = 1 if s3aq49==1
replace pest_herb_usage = 0 if s3aq49==2
label var pest_herb_usage "Any pesticide/herbicide used on plot"


********************PLOT USE**********************
//total all land within the household that is cultivated

gen landuse_cultivated=.
replace landuse_cultivated = 1 if s3aq3==1
**s3aq3!=. below keeps that missings as missing
replace landuse_cultivated = 0 if s3aq3!=1 & s3aq3!=.
replace landuse_cultivated = . if s3aq3==.
label var landuse_cultivated "Did you cultivate this plot, section 3 of ag survey"
**take those plots and find their area - all other plots should be 0 or .
egen landuse_cultivated_ha = sum(plot_area) if landuse_cultivated ==1 & plot_tag==1 & plot_area!=., by(hhid)
bysort hhid: egen totplot=max(landuse_cultivated_ha) 
replace landuse_cultivated_ha=totplot
replace landuse_cultivated_ha=0 if landuse_cultivated==0 
replace landuse_cultivated_ha=. if landuse_cultivated==. 
drop totplot 
label var landuse_cultivated_ha "Total area cultivated, ha (s3aq3)"

*******************INTERCROPPING*****************
**ic: intercropped
gen landuse_ic_ap =.
replace landuse_ic_ap = 1 if s4aq6==1 | s6aq5 ==1 | s6bq5 ==1
replace landuse_ic_ap = 0 if s4aq6==2 | s6aq5 ==2 | s6bq5 ==2
label var landuse_ic_ap "Was the plot intercropped"

//now: can drop obs. with no zaocode
drop if zaocode ==.  //641 dropped

********LABOR VARS********* 

*Plot number
	*count number of plots (takes a few steps)
encode plotnum, generate(plot_number) // make plotnum numeric

egen nmbr_plots = count(plot_number), by(hhid) 

// obs tagged with 2 or higher means that they are repeat plots (aka have more than one crop on the plot and thus it repeats)
la var nmbr_plots "(plotnum) count of plots by household"
la var plot_number "encode(plotnum) step variable to nmbr_plots"


	*HH Labor - *LRS ONLY*
//Total: all hh labor
drop s3aq61_id* // drop network id so that we can sum across the variables
egen hh_labor_days = rowtotal(s3aq61_*) if plot_tag ==1, missing
la var hh_labor_days "(rowtotal s3aq61) total number of HH labor days on plot - all crops"

*Lists here, run next section all together
local prep s3aq61_1 s3aq61_2 s3aq61_3 s3aq61_4 s3aq61_5 s3aq61_6 s3aq61_7 s3aq61_8 s3aq61_9 s3aq61_10 s3aq61_11 s3aq61_12
local weed s3aq61_13 s3aq61_14 s3aq61_15 s3aq61_16 s3aq61_17 s3aq61_18 s3aq61_19 s3aq61_20 s3aq61_21 s3aq61_22 s3aq61_23 s3aq61_24
local harvest s3aq61_25 s3aq61_26 s3aq61_27 s3aq61_28 s3aq61_29 s3aq61_30 s3aq61_31 s3aq61_32 s3aq61_33 s3aq61_34 s3aq61_35 s3aq61_36

//HH labor on land preparation/planting
egen hh_prep_days = rowtotal(`prep') if plot_tag ==1, missing
la var hh_prep_days "(rowtotal s3aq61_1-_12) total number of HH labor days spent on preparation and planting"

//HH labor on weeding
egen hh_weed_days = rowtotal(`weed') if plot_tag ==1, missing
la var hh_weed_days "(rowtotal s3aq61_13-_24) total number of HH labor days spent on weeding"

//HH labor on harvesting
egen hh_harvest_days = rowtotal(`harvest') if plot_tag ==1, missing
la var hh_harvest_days "(rowtotal s3aq61_25-36) total number of HH labor days spent on harvesting"

**will calculate labor days per hectare after collapse


	*Hired Labor - *LRS ONLY* - note child days not asked in W1
local hired_vars s3aq63_1 s3aq63_2 s3aq63_4 s3aq63_5 s3aq63_7 s3aq63_8 
egen hired_labor_days = rowtotal(`hired_vars') if s3aq62==1 & plot_tag ==1, missing
la var hired_labor_days "(s3aq63) total number of hired labor days"

*Lists here, run next section all together //the question numbering here doesn't seem to have any reason behind it
local prep1 s3aq63_1 s3aq63_2 
local weed1 s3aq63_4 s3aq63_5 
local harvest1 s3aq63_7 s3aq63_8 

//Hired labor on land prep/planting: total man/woman
egen hired_prep_days = rowtotal(`prep1') if plot_tag ==1, missing
la var hired_prep_days "(s3aq63_1-2) total number of hired labor days spent on preparation and planting"

//Hired labor on weeding: total man/woman
egen hired_weed_days = rowtotal(`weed1') if plot_tag ==1, missing
la var hired_weed_days "(s3aq63_4-5) total number of hired labor days spent on weeding"

//Hired labor on harvesting: total man/woman
egen hired_harvest_days = rowtotal(`harvest1') if plot_tag ==1, missing
la var hired_harvest_days "(s3aq63_7-8) total number of hired labor days spent on harvesting"

*Check for any unrealistic reporting
sum s3aq61* s3aq63* 

*Make variables for the other data we want to keep, fill in just once per plot so we can sum to HH
gen hired_women_days_prep = s3aq63_2 if plot_tag ==1
gen hired_men_days_prep = s3aq63_1 if plot_tag ==1
gen hired_women_days_weed = s3aq63_5 if plot_tag ==1
gen hired_men_days_weed = s3aq63_4 if plot_tag ==1
gen hired_women_days_harv = s3aq63_8 if plot_tag ==1
gen hired_men_days_harv = s3aq63_7 if plot_tag ==1

la var hired_women_days_prep "(s3aq63_2) total number of hired women days spent on preparation and planting"
la var hired_men_days_prep "(s3aq63_1) total number of hired men days spent on preparation and planting"
la var hired_women_days_weed "(s3aq63_5) total number of hired women days spent on weeding"
la var hired_men_days_weed "(s3aq63_4) total number of hired men days spent on weeding"
la var hired_women_days_harv "(s3aq63_8) total number of hired women days spent on harvesting"
la var hired_men_days_harv "(s3aq63_7) total number of hired men days spent on harvesting"

//replace with zeros if they answered they didn't hire any labor on the plot 
local hiredvars hired_* 
foreach x of varlist `hiredvars' {
replace `x' = 0 if s3aq62 == 2
} 


//Bysort by household so we can use a max collapse - use a loop. Note: using TOTAL instead of SUM because TOTAL allows the missing option
local laborvars hh_labor_days hh_prep_days hh_weed_days hh_harvest_days hired_* 

foreach x of varlist `laborvars' {
	egen tot_`x' = total(`x') if plot_tag==1, by(hhid) missing
bysort hhid: egen totplot=max(tot_`x') 
replace tot_`x'=totplot 
drop totplot 
	}


******************AREA PLANTED*******************

*s4aq3 "Was crop planted in entire area of plot?"
*s4aq4 "Approx how much of the plot was planted with [crop]? 1/4, 1/2, 3/4"

*recode to get numeric values and make step variable for crops planted on less than 100% of the plot:
recode s4aq4 (1=.25) (2=.5) (3=.75)
gen arpl_portion_ha= s4aq4*plot_area
la var arpl_portion_ha "(s4aq4 plot_area) portion of crop area planted in hectares (step variable to area_planted_ha)"

gen area_planted_ha = .
replace area_planted_ha = plot_area if s4aq3==1
replace area_planted_ha = arpl_portion_ha if s4aq3==2
la var area_planted_ha "(s4aq3-4 plot_area) crop area planted in hectares (gps if available, else FR)"


*************AREA HARVESTED********************
*s4aq15 "What was the quantity harvested?(KGs)"
gen harv_quant_kg = .
replace harv_quant_kg = s4aq15
replace harv_quant_kg = 0 if s4aq1==2 & s4aq2==3 //replace with zero if they didn't harvest any crop due to destruction
label var harv_quant_kg "(s4aq15) Harvested Quantity(KGs), LRS_2008"

*s4aq16 "What is the estimated value of the harvest crop? (TZ_Shillings)"
gen harv_value_tsh = .
replace harv_value_tsh = s4aq16
label var harv_value_tsh "(s4aq16) Value of Harvested Crop (Tz_Shillings), LRS_2008"

*s4aq8 "What was the area harvested in the LRS 2008?"
*replace with zero if answered no to s4aq1: "Did you harvest any [crop] on this plot in LRS 2008"
* AND s4aq2 "Why didn't you harvest any [crop] on this plot" 1. not mine, 2. still in plot, 3. destruction, 4. other
* NOTE: We are only converting to zero if they didn't harvest due to DESTRUCTION (CODE=3)
gen area_harvested_ac = s4aq8
replace area_harvested_ac =0 if s4aq1==2 & s4aq2==3
la var area_harvested_ac "(s4aq1-8) area harvested in acres, farmer report, capped at plot_area"

*convert to hectares
gen area_harvested_ha = .
replace area_harvested_ha = area_harvested_ac* 0.404685642

*cap area harvested at plotsize if reported area harvested was over GPS plotsize
replace area_harvested_ha = plot_area if area_harvested_ha > plot_area & area_harvested_ha !=. //279 changes
la var area_harvested_ha "(s4aq1-8) area harvested in hectares, farmer report, capped at plot_area"

//fruits
gen grew_fruit = 0
replace grew_fruit = 1 if s6aq2 !=. //if they had at least one fruit tree
la var grew_fruit "household grew any fruit crops in 2008 (s6aq2)"

gen number_fruits = s6aq2
la var number_fruits "number of plants/trees on the plot (s6aq2)"

gen number_fruits_12months = s6aq4
la var number_fruits_12months "number of trees/plants planted in last 12 months (s6aq4)"

gen harvest_quant_fruit = s6aq8
la var harvest_quant_fruit "total amount of fruit harvested (s6aq8)"

//permanent crops
gen grew_perm = 0
replace grew_perm = 1 if s6bq2 !=. //if they had at least one permanent crop plant
la var grew_perm "household grew any permanent crops in 2008 (s6bq2)"

gen number_perm = s6bq2
la var number_perm "number of plants/trees on the plot (s6bq2)"

gen number_perm_12months = s6bq4
la var number_perm_12months "number of trees/plants planted in last 12 months (s6bq4)"

gen harvest_quant_perm = s6bq8
la var harvest_quant_perm "total amount of permanent crop harvested (s6bq8)"


********MAKE VARIABLES THAT SUM ALLOCATION BY CROP//We could have instead used the collapse to sum up area (although rounding is slightly different).
//However, we have based all our analysis variables and descriptives on these variables, so it will be easier not to delete them.
egen crop_allocation = sum(plot_area) if plot_area!=., by(hhid zaocode)
bysort hhid zaocode: egen totplot=max(crop_allocation) 
replace crop_allocation=totplot 
drop totplot 

egen arpl_crop = sum(area_planted_ha) if area_planted_ha!=., by(hhid zaocode) 
bysort hhid zaocode: egen totplot=max(arpl_crop ) 
replace arpl_crop =totplot 
drop totplot 

egen harv_quant_annual_crop = sum(harv_quant_kg) if harv_quant_kg!=., by(hhid zaocode)
bysort hhid zaocode: egen totplot=max(harv_quant_annual_crop) 
replace harv_quant_annual_crop =totplot 
drop totplot 

egen harv_quant_perm_crop = sum(harvest_quant_perm) if harvest_quant_perm!=., by(hhid zaocode)
bysort hhid zaocode: egen totplot=max(harv_quant_perm_crop) 
replace harv_quant_perm_crop =totplot 
drop totplot 

egen harv_quant_fruit_crop = sum(harvest_quant_fruit) if harvest_quant_fruit!=., by(hhid zaocode)
bysort hhid zaocode: egen totplot=max(harv_quant_fruit_crop) 
replace harv_quant_fruit_crop =totplot 
drop totplot 

egen arhv_crop = sum(area_harvested_ha) if area_harvested_ha!=., by(hhid zaocode)
bysort hhid zaocode: egen totplot=max(arhv_crop) 
replace arhv_crop =totplot 
drop totplot 


//three plotsize_ha ==. and one sum_plotsize_ha==0, but none of these are maize observations.
la var crop_allocation "sum of all plot area for crop, by household (arpl, gps if available, else FR)"
la var arpl_crop "sum of total area planted for annual crop, by household (gps if available, else FR)"
la var harv_quant_annual_crop "sum of harvest quantity for annual crop, by household"
la var harv_quant_perm_crop "sum of harvest quantity for permanent crop, by household"
la var harv_quant_fruit_crop "sum of harvest quantity for fruit crop, by household"
la var arhv_crop "sum of area harvested for annual crop, by household (farmer report capped at plotsize)"

count if crop_allocation > sum_plot_area & crop_allocation !=. //0
count if arpl_crop > sum_plot_area & arpl_crop !=.  //0
isid hhid plotnum zaocode, missok

**if you want to preserve more variables, add them to these local lists
local countcollapse plot_cultivated
local maxcollapse grew_fruit grew_perm grew_annual crop_allocation sum_plot_area arpl_crop /// 
harv_quant_annual_crop harv_quant_fruit_crop harv_quant_perm_crop arhv_crop /// 
landuse_cultivated_ha tot* nmbr_plots /// 
landuse_ic_ap soil_type soil_quality plot_irrigated org_fert inorg_fert pest_herb_usage 

local sumcollapse plot_area area_planted_ha harv_quant_kg harv_value_tsh area_harvested_ha number_fruits number_fruits_12months /// 
harvest_quant_fruit number_perm number_perm_12months harvest_quant_perm fr_hh

collapse (count) `countcollapse' (max) `maxcollapse' (sum) `sumcollapse', by (hhid zaocode) 

//label variables
la var sum_plot_area "sum of all HH plots in ha LRS 2008 - GPS-based if available, else farmer-report"
la var plot_area "plot area measure, ha - GPS-based if they have one, farmer-report if not"
la var area_planted_ha "(s4aq3-4 plot_area) crop area planted in ha (gps if available, else FR)"
la var harv_quant_kg "(ag4a_15) Harvested Quantity(KGs), LRS_2008"
la var harv_value_tsh "(ag4a_16) Value of Harvested Crop (Tz_Shillings), LRS_2008"
la var area_harvested_ha "(ag4a_06-08) area harvested in hectares, farmer report, cap at plot_area"
la var number_fruits "number of plants/trees on the plot (ag6a_02)"
la var number_fruits_12months "number of trees/plants planted in last 12 months (ag6a_04)"
la var harvest_quant_fruit "total amount of fruit harvested (ag6a_08)"
la var number_perm "number of plants/trees on the plot (ag6b_02)"
la var number_perm_12months "number of trees/plants planted in last 12 months (ag6b_04)"
la var harvest_quant_fruit "total amount of permanent crop harvested (ag6b_08)"
la var grew_fruit "household grew any fruit crops in 2008 (ag6a_02)"
la var grew_perm "household grew any permanent crops in 2008 (ag6b_02)"
la var grew_annual "hh grew annual crops in 2008 (answered section 4)"
la var plot_cultivated "number of plots of this crop cultivated by household during LRS 2008 (ag3a_38)"
la var crop_allocation "sum of all plot area for crop, by household (arpl, gps if available, else FR)"
la var arpl_crop "sum of total area planted for annual crop, by household (gps if avail, else FR)"
la var harv_quant_annual_crop "sum of harvest quantity for annual crop, by household"
la var harvest_quant_perm "sum of harvest quantity for permanent crop, by household"
la var harvest_quant_fruit "sum of harvest quantity for fruit crop, by household"
la var arhv_crop "sum of area harvested for annual crop, by household (farmer report cap at plotsize)"
la var landuse_cultivated_ha "Total area cultivated, ha (ag3a_03)" 
la var fr_hh "number of plots without a GPS measure (farmer-reported area used)"
la var nmbr_plots "(plotnum) count of plots by household"
la var tot_hired_women_days_prep "(s3aq63_2) total number of hired women days spent on prep and planting"
la var tot_hired_men_days_prep "(s3aq63_1) total number of hired men days spent on prep and planting"
la var tot_hired_women_days_weed "(s3aq63_5) total number of hired women days spent on weeding"
la var tot_hired_men_days_weed "(s3aq63_4) total number of hired men days spent on weeding"
la var tot_hired_women_days_harv "(s3aq63_8) total number of hired women days spent on harvesting"
la var tot_hired_men_days_harv "(s3aq63_7) total number of hired men days spent on harvesting"
la var tot_hired_labor_days "(s3aq63) total number of hired labor days"
la var tot_hired_prep_days "(s3aq63_1-2) total number of hired labor days spent on prep and planting"
la var tot_hired_weed_days "(s3aq63_4-5) total number of hired labor days spent on weeding"
la var tot_hired_harvest_days "(s3aq63_7-8) total number of hired labor days spent on harvesting"
la var tot_hh_labor_days "(rowtotal ag3a_70) total number of HH labor days on plot - all crops"
la var tot_hh_prep_days "(rowtotal s3aq61_1-_12) total number of HH labor days spent on prep and planting"
la var tot_hh_weed_days "(rowtotal s3aq61_13-_24) total number of HH labor days spent on weeding"
la var tot_hh_harvest_days "(rowtotal s3aq61_25-36) total number of HH labor days spent on harvesting"
label var landuse_ic_ap "Dummy if plot cultivated is intercropped, all crops"
label var soil_type "(s3aq7) Type of soil on the plot, 1=sandy, 2=loam, 3=clay, 4=other"
label var soil_quality "(s3aq8) Soil quality on the plot, 1=good, 2=average, 3=bad"
label var plot_irrigated "(s3aq15) Dummy if plot was irrigated"
label var org_fert "(s3aq37) Dummy if used organic fertilizer"
label var inorg_fert "(s3aq43) Dummy if used inorganic fertilizer"
label var pest_herb_usage "(s3aq49) Dummy if used pesticides or herbicides"


count if arpl_crop > sum_plot_area & arpl_crop !=. //0
count if crop_allocation > sum_plot_area & crop_allocation !=. //0

save "$collapse/plot_to_crop_hh_shiny.dta", replace


/////////MERGE ALL DATASETS AT CROP LEVEL

clear
use "$input\SEC_QNFLOW" //start with filter questions, HH level
*2429 observations (households in dataset)

**Merge plot-crop dataset collapsed to HH
merge 1:m hhid using "$collapse/plot_to_crop_hh_shiny.dta", gen (_merge_plot_level)
*9337 matched, 249 not matched from master

**Annual crop production and sales (hh-crop level) 
merge m:1 hhid zaocode using "$input/SEC_5A", keep (1 3) gen (_merge_SEC_5A)
**Unique ID: hhid zaocode
*4289 matched 
*5297 not matched from master //perm crops, or additional crops per HH

**Fruit crop production and sales (hh-crop level)
merge m:1 hhid zaocode using "$input/SEC_7A", keep (1 3) gen (_merge_SEC_7A)
**Unique ID: hhid zaocode
*2481 matched, 7105 not matched from master

**Permanent crop production and sales (hh-crop level)
merge m:1 hhid zaocode using "$input/SEC_7B", keep (1 3) gen (_merge_SEC_7B)
**Unique ID: hhid zaocode
*1518 matched, 8068 not matched from using



/////////MERGE IN COLLAPSED DATA FILES 
**Merge in Household Data Set - Collapsed at the Household Level
merge m:1 hhid using "$collapse\HH_merge.dta", keep (1 3) gen (_merge_HHDATA)
*Matched: 9586, not keeping non-cultivating hh

**Merge in maize consumption
merge m:1 hhid using "$collapse/HH_SEC_K1_maize_consumption.dta", keep (1 3) gen (_merge_maizecons)
*Matched: 9586

////////////MERGE IN SURVEY WEIGHTS (HH level)
merge m:1 hhid using "$input/weights", keep (1 3) gen (_merge_weights)
*9586 matched


////////////MERGE IN GEOVARIABLES
merge m:1 hhid using "$input/Geovariables/HH_Geovariables_Y1", keep (1 3) gen (_merge_hhgeo)
**Unique ID: HHID
*8538 matched, 1048 not matched from master


///////////MERGE IN CONSUMPTION (HH level)
merge m:1 hhid using "$input/Geovariables/TZY1_HH_Consumption", keep (1 3) gen (_merge_cons)
*9586 matched


////////////DROP NON-CULTIVATING OBSERVATIONS
drop if zaocode == . 
codebook hhid
*249 observations dropped. Now 9337 observations, 2180 households.



///////////////////////////
//						 //
//RENAME FOR PANEL MERGE //
//						 //
///////////////////////////

**here we make sure all variable names match across years, then add _2008 to the end of each variable.

*Rename to 2012 var names
local vars2008 s5aq1 s5aq2 /*
*/ s5aq3 s5aq4_1 s5aq5 s5aq6 s5aq7 s5aq8 s5aq9 s5aq10 s5aq11 s5aq12 s5aq13 s5aq14 s5aq15 s5aq16 s5aq17 s5aq18 s5aq19 s5aq20 s5aq21 s5aq22 s5aq23 fisherb1c1 /*
*/ intmonth intyear crops01 crops02 crops03 crops04 crops05 crops06 crops07 crops08 crops09 clim01 clim02 clim03 clim04 clim05 crops10 crops11 crops12 /*
*/ crops13 crops14 crops15 crops16 crops17 crops18 dist02 dist03 dist04 dist05 dist06 soil01 soil05 soil06 soil07 soil08 soil09 soil10 soil11 dist01 /*
*/ district ward rural sa1q9 sa2q20 sa2q23 sa2q16 s7aq2 s7aq3 s7aq4 s7aq5_1 s7aq5_2 s7aq6 s7aq7 s7aq8 s7aq9 s7aq10 s7aq11 s7aq12 s7aq13 s7aq14 

local vars2010 ag5a_01 ag5a_02 ag5a_03 ag5a_04 ag5a_05 ag5a_06 ag5a_12 ag5a_13 ag5a_18 ag5a_19 ag5a_20 ag5a_21 ag5a_22 ag5a_29 ag5a_30 ag5a_31 ag5a_32 ag5a_23 /*
*/ ag5a_24 ag5a_25 ag5a_26 ag5a_27 ag5a_28 fisherb3c3 hh_a18_2 hh_a18_3 crops01 crops02 crops03 crops04 crops05 crops06 crops07 crops08 crops09 clim01 /*
*/ clim02 clim03 clim04 clim05 crops10 crops11 crops12 crops13 crops14 crops15 crops16 crops17 crops18 dist01 dist02 dist03 dist05 dist04 plot03 soil05 /*
*/ soil06 soil07 soil08 soil09 soil10 soil11 plot01 hh_a02_1  hh_a03_1 y3_rural hh_a10 hh_a20 hh_a23 hh_a16 ag7a_02 ag7a_03 ag7a_04 ag7a_07_1 /*
*/ ag7a_07_2 ag7a_13 ag7a_14 ag7a_15 ag7a_16 ag7a_08 ag7a_09 ag7a_10 ag7a_11 ag7a_12 


**Use a loop to match up the two lists
local n : word count `vars2008'
*run loop 
forvalues i=1/`n'{
*set x and y to var order
local z : word `i' of `vars2008'
local x : word `i' of `vars2010'
rename (`z') (`x')
}



**add _2008 to the end of each variable
foreach x of varlist *{
rename `x' `x'_2008
}

//reversing these renames, because we need to merge on them
rename zaocode_2008 zaocode

//this should be ready for the panel merge, because hhid needs to be renamed hhid_2008 in order to merge to W2.
isid hhid_2008 zaocode

*create panel HH ID called hhid_p ('p' for panel)
*add '01' to end of 2008 hhid to match primary hhid in 2010
gen str2 newid = "01"
generate hhid_p = hhid_2008 + newid 
drop newid
la var hhid_p "unique panel identifier"

gen wave1 = 1
la var wave1 "observation existed in wave 1"

////////////SAVE FOR PANEL MERGE 
save "$output/wave1_merged_shiny.dta", replace

