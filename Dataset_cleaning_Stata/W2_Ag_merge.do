//////////////////////////////////////////////////////////////////////////////////////////////////////////////
************************************ Basic Documentation *****************************************************
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
*Title/Purpose of Do File: Tanzania LSMS-ISA W2(2010) - Ag survey - Prepare data for Shiny agricultural productivity app
*Unique identifiers (level): y2_hhid zaocode
*Author(s): Katie Harris, Maggie Beetstra
*Date started: 11/27/15
*Date completed: 8/8/16

*Checked by: Melissa Greenaway
*Date: 1/21/16
*Checked by: David Coomes
*Date: 1/12/17

*This file to be run before Three-panel_merge and W1-3_Cluster_Prices

//SET DIRECTORIES - make sure to reset these 
clear
global input "FILEPATH" //where the agricultural module is downloaded, reset
global input2 "FILEPATH" //where the household module is downloaded, reset
global output "FILEPATH\Merged Data Shiny" //set up an output folder to save .dtas to use in the panel merge, reset 
global collapse "FILEPATH\Collapse Data Shiny" //set up an output folder for collapsed .dtas, reset 

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
************************************************COLLAPSING***************************************************
/////////////////////////////////////////////////////////////////////////////////////////////////////////////


************************************************
//////MAIZE OWN-CONSUMPTION: HH Data SEC K////// 
************************************************
**data is presented at the item level, we will need to collapse it to the household level. 
**the only product we care about is maize, item codes 0103, 0104, and 0105, that comes from own production, question 5. 
**also preserve total quantity consumed in case we want to use proportion of the total that came from own production. 
clear
use "$input2\HH_SEC_K1"

**Generating variables
gen cons_tot_greenmaize_kg =.
replace cons_tot_greenmaize_kg = hh_k02_2 if hh_k02_1 == 1 & itemcode == 0103
replace cons_tot_greenmaize_kg = hh_k02_2/1000 if hh_k02_1 == 2 & itemcode == 0103
replace cons_tot_greenmaize_kg = 0 if hh_k01_2 == 2 & itemcode ==0103

gen cons_tot_maizegrain_kg =.
replace cons_tot_maizegrain_kg = hh_k02_2 if hh_k02_1 == 1 & itemcode == 0104
replace cons_tot_maizegrain_kg = hh_k02_2/1000 if hh_k02_1 == 2 & itemcode == 0104
replace cons_tot_maizegrain_kg = 0 if hh_k01_2 == 2 & itemcode ==0104

gen cons_tot_maizeflour_kg =.
replace cons_tot_maizeflour_kg = hh_k02_2 if hh_k02_1 == 1 & itemcode == 0105
replace cons_tot_maizeflour_kg = hh_k02_2/1000 if hh_k02_1 == 2 & itemcode == 0105
replace cons_tot_maizeflour_kg = 0 if hh_k01_2 == 2 & itemcode ==0105

gen cons_own_greenmaize_kg =0
replace cons_own_greenmaize_kg = hh_k05_2 if hh_k05_1 == 1 & itemcode == 0103
replace cons_own_greenmaize_kg = hh_k05_2/1000 if hh_k05_1 == 2 & itemcode == 0103

gen cons_own_maizegrain_kg =0
replace cons_own_maizegrain_kg = hh_k05_2 if hh_k05_1 == 1 & itemcode == 0104
replace cons_own_maizegrain_kg = hh_k05_2/1000 if hh_k05_1 == 2 & itemcode == 0104

gen cons_own_maizeflour_kg =0
replace cons_own_maizeflour_kg = hh_k05_2 if hh_k05_1 == 1 & itemcode == 0105
replace cons_own_maizeflour_kg = hh_k05_2/1000 if hh_k05_1 == 2 & itemcode == 0105

////////////COLLAPSE TO HH LEVEL

local consumption cons_*
collapse (max) `consumption', by (y2_hhid)

la var cons_tot_greenmaize_kg "(hh_k02) total household weekly consumption of green maize, kg"
la var cons_tot_maizegrain_kg "(hh_k02) total household weekly consumption of maize grain, kg"
la var cons_tot_maizeflour_kg "(hh_k02) total household weekly consumption of maize flour, kg"
la var cons_own_greenmaize_kg "(hh_k05) household weekly consumption from own production of green maize, kg"
la var cons_own_maizegrain_kg "(hh_k05) household weekly consumption from own production of maize grain, kg"
la var cons_own_maizeflour_kg "(hh_k05) household weekly consumption from own production of maize flour, kg"

save "$collapse/HH_SEC_K1_maize_consumption.dta", replace


************************************************
///////////HOUSEHOLD SECTION////////////////////
************************************************
*We only need to preserve a few variables from this section: age of HH head, education of HH head, gender of HH head
clear
use "$input2\HH_SEC_A.dta"

//Merge in section B: Household Member Roster
**Unaltered .dta file
sort y2_hhid
merge 1:m y2_hhid using "$input2\HH_SEC_B", generate (_merge_HH_SEC_B)
//matched: 20,559
//not matched:0

//Merge in section C: Education
**Unaltered .dta file
merge 1:1 y2_hhid indidy2 using "$input2\HH_SEC_C", generate(_merge_HH_SEC_C)
//matched: 20,559
//not matched:0

//Generate variable for HH size (note there is an "adult equivalent" hh size number in consumption file)
egen hh_size = count(indidy2), by(y2_hhid) 
la var hh_size "count (indidy2): number of household members"

**104 vars - only keep necessary vars - Age, edu, sex, HH head
keep y2_hhid y2_weight y2_rural clusterid strataid region district ward ea indidy2 hh_size hh_a11 hh_b05 hh_b02 hh_b04 hh_c0*   
isid y2_hhid indidy2
//hh_b05 identifies the HH head. Dropping others
drop if hh_b05!=1
isid y2_hhid
//n=3,924 HH

save "$collapse/HH_merge.dta", replace



///////////////////////////////////////////////
///											///
///					MERGING					///
///											///
///////////////////////////////////////////////

///////////////Begin by merging all plot-crop level data together

****************** PREP PERMANENT AND TREE CROPS (REMOVE DUPLICATES)************************************* 


**6B: Permanent crops
clear
use "$input\AG_SEC6B"
*isid y2_hhid plotnum zaocode, missok //duplicates
duplicates tag y2_hhid plotnum zaocode, gen(duptag)
tab duptag // lots of duplicates-- preventing a merge!
*br if duptag !=0 

sort y2_hhid plotnum zaocode // this code give unique dup identifier 
quietly by y2_hhid plotnum zaocode:  gen dups = cond(_N==1,0,_n)
replace dups=. if dups==1 | dups ==0
label var dups "zaocode duplicates"

gen zaocode2=. //assign a different zaocode value to duplicates so we can continue to track them if desired
replace zaocode2=399+dups if zaocode==304 & dups!=. //for timber duplicates: 40_
replace zaocode2=499+dups if zaocode==303 & dups!=. //for firewood/fodder duplicates 50_
replace zaocode2=899+dups if zaocode==998 & dups!=. //for "other" duplicates 90_
replace zaocode2=1799+dups if zaocode==305 & dups!=. //for medicinal plant duplicates 180_
replace zaocode2=1399+dups if zaocode==306 & dups!=. //for fence tree duplicates 140_
label var zaocode2 "new zaocode for duplicates"

replace zaocode=zaocode2 if dups!=. //replace zaocode value with new zaocode value if it is a duplicate
drop dups duptag //drop step variables

isid y2_hhid plotnum zaocode
save "$collapse\AG_SEC6B_prepped.dta", replace


**7A: Fruit crops
clear
use "$input\AG_SEC7B"
*isid y2_hhid zaocode, missok
duplicates tag y2_hhid zaocode, gen(duptag)
tab duptag // 12 duplicates-- preventing a merge!
*br if duptag !=0 

sort y2_hhid zaocode // this code give unique dup identifier
quietly by y2_hhid zaocode:  gen dups = cond(_N==1,0,_n)
replace dups=. if dups==1 | dups ==0
label var dups "zaocode duplicates"

gen zaocode2=.
replace zaocode2=399+dups if zaocode==304 & dups!=. //for timber duplicates: 40_
replace zaocode2=899+dups if zaocode==998 & dups!=. //for "other" duplicates 90_
replace zaocode2=902 if zaocode==995 & dups!=. //for "other" duplicates 90_
replace zaocode2=903 if zaocode==996 & dups!=. //for "other" duplicates 90_
replace zaocode2=904 if zaocode==997 & dups!=. //for "other" duplicates 90_
replace zaocode2=1799+dups if zaocode==305 & dups!=. //for medicinal plant duplicates 180_

replace zaocode=zaocode2 if dups!=. //replace zaocode value with new zaocode value if it is a duplicate
drop dups duptag //no longer needed

isid y2_hhid zaocode, missok
save "$collapse\AG_SEC7B_prepped.dta", replace


**********************	CROP LEVEL	*******************************
**First, we will merge all the data at the CROP LEVEL together: annual, permanent, and tree crops. 
**There will be one observation per hhid/plotnum/zaocode. Then afterward we will merge this to the hh/plot level data 
//so that all crop observations are associated with their plot data (doesn't work in reverse order)
**These datasets have duplicate problems (y3_hhid plotnum zaocode do not uniquely identify) so we will deal with them each separately.

**Start with 4A: crops by plots, LRS (annual crops)
clear
use "$input\AG_SEC4A.dta"
//n=8206
isid y2_hhid plotnum zaocode, missok
drop if zaocode ==. //2205 dropped
gen grew_annual = 1
la var grew_annual "hh grew annual crops in 2010 (answered section 4)"

/////////////////////////////////////////////////////////////////////

merge 1:1 y2_hhid plotnum zaocode using "$input\AG_SEC6A.dta", gen (_plot_fruit)
**6 matched (this matched "other" to "other" or they had reported fruit as an annual crop), 10785 not matched from master (annual crops), 4790 not matched from using (fruit crops)

**add in 6B: other permanent crops
merge 1:1 y2_hhid plotnum zaocode using "$collapse\AG_SEC6B_prepped.dta", gen (_plot_perm)
**22 matched (hh reported crop in both fruit AND permanent), 10769 not matched from master (annual and fruit), 3968 not matched from using (permanent)
isid y2_hhid plotnum zaocode, missok

replace grew_annual = 0 if grew_annual ==.
save "$collapse\crop_level.dta", replace 



***************************************************************************************
************	PLOT LEVEL and PLOT-CROP LEVEL TO HH-CROP LEVEL	   ******************** 
***************************************************************************************

********** PLOT LEVEL DATA *************
//We will begin by merging the plot-level datasets and creating the plot-level variables we need. Afterwards we will merge the plot-crop sections and create the crop-level variables. 
//For this analysis, we will have to collapse to the crop-hh level to merge panels.

**The following datasets merged into this file come from the original .dta files provided from the world bank
**becase these files are already provided at the plot level (meaning that household ID and PlotID are the unique identifiers)

**Merge in Data from the 2010 Survey - Agricultural Sections at the Plot Level
**Section 2A of the Agricultural Survey at the Plot Level: 2010 Long Rainy Season (LRS)
clear
use "$input\AG_SEC2A.dta" 
*Observations: 6,038
*Variables: 8


**Merge in Section 3A of the Agricultural Survey at the Plot Level: 2010 Long Rainy Season (LRS)
merge 1:1 y2_hhid plotnum using "$input\AG_SEC3A.dta", gen (_merge_SEC3A_2010)
*Matched: 6,038
*Not Matched: 0
*Variables: 173

**There is a variable called zaocode which represents the main crop on the plot. We need to rename this so zaocode can be a unique ID.
rename zaocode main_crop
isid y2_hhid plotnum

**Merge in Section 4A, 6A, 6B 2010 LRS -- this will merge in multiple crops per plot (annual, fruit, permanent)
**DATASET WILL NOW BE AT CROP LEVEL
merge 1:m y2_hhid plotnum using "$collapse\crop_level.dta", keep (1 3) gen (_merge_crop_level_2010) 
*Matched: 14,757
*Not Matched: 753 from master
isid y2_hhid plotnum zaocode, missok 

merge m:1 y2_hhid plotnum using "$input\TZY2_PlotGeovariables.dta" , keep (1 3) gen (_merge_plot_geo)
*13,165 matched, 2345 not matched from master (non-cultivating)


//////////GENERATE PLOT-LEVEL VARIABLES BEFORE COLLAPSE
gen plot_cultivated =1 if ag3a_38==1
replace plot_cultivated =0 if ag3a_38==2
la var plot_cultivated "plot cultivated during LRS 2010 (ag3a_38)"

**************Plot size************
gen plotsize_acres = ag2a_04
la var plotsize_acres "(ag2a_04) farmer reported plot size in acres"

gen plotsize_ha = plotsize_acres* 0.404685642
la var plotsize_ha "(ag2a_04) farmer reported plot size in hectares"

gen plotsize_acres_gps = ag2a_09
la var plotsize_acres_gps "(ag2a_09) GPS measured plot size in acres"

gen plotsize_ha_gps = plotsize_acres_gps* 0.404685642
la var plotsize_ha_gps "(ag2a_09) GPS measured plot size in hectares"

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

////////////MAKE LANDHOLDING VARS
//create tag for the first plotnum by hhid so that we can sum plotsize in the next variables
egen plot_tag =tag(y2_hhid plotnum) 
la var plot_tag "plot-level tag"

//GPS-based if they have one, farmer-report if not
egen sum_plot_area = sum(plot_area) if plot_tag==1 & plot_area!=., by(y2_hhid)
// the code below is needed so that the number of plots fills in by hhid (run piece by piece if unclear)
// in otherwords, egen above will create missings for duplicate plots and we want those missings to fill in with the value
// so that every plot has the sum of plotsizes (total landholding) at each level of the data
bysort y2_hhid: egen totplot=max(sum_plot_area) 
replace sum_plot_area=totplot // tell it to back fill so that missings are changed to the number of plots
drop totplot // don't need it
la var sum_plot_area "sum(plot_area) sum of all HH plots in ha LRS 2012 - GPS-based if they have one, farmer-report if not"

**********************SOIL************************
//looking at soil type and soil quality

rename ag3a_09 soil_type
label var soil_type "Soil type of the plot"
rename ag3a_10 soil_quality
label var soil_quality "Soil quality of the plot"

*******************IRRIGATION*********************
gen plot_irrigated=.
replace plot_irrigated = 1 if ag3a_17==1
replace plot_irrigated = 0 if ag3a_17==2
label var plot_irrigated "Plot irrigated"

*******************FERTILIZER*********************
gen org_fert=.
replace org_fert = 1 if ag3a_39==1
replace org_fert = 0 if ag3a_39==2
label var org_fert "Organic fertilizer used on plot"

gen inorg_fert=.
replace inorg_fert = 1 if ag3a_45==1
replace inorg_fert = 0 if ag3a_45==2
label var inorg_fert "Inorganic fertilizer used on plot"

***************PESTICIDE/HERBICIDE****************
gen pest_herb_usage=.
replace pest_herb_usage = 1 if ag3a_58==1
replace pest_herb_usage = 0 if ag3a_58==2
label var pest_herb_usage "Any pesticide/herbicide used on plot"



********************PLOT USE**********************
//goal to figure out the amount of land (plots summed) and then determine how much of that land is used for each purpose

gen landuse_cultivated=.
replace landuse_cultivated = 1 if ag3a_03==1
**ag3a_03!=. below keeps that missings as missing
replace landuse_cultivated = 0 if ag3a_03!=1 & ag3a_03!=.
label var landuse_cultivated "Did you cultivate this plot (ag3a_03)"
**add up their area and fill in for all obs. of the HH
egen landuse_cultivated_ha = sum(plot_area) if landuse_cultivated ==1 & plot_tag==1 & plot_area!=., by(y2_hhid)
// the code below is needed so that the area of plots fills in by y2_hhid (run piece by piece if unclear)
// in otherwords, egen above will create missings for duplicate plots and we want those missings to fill in with the value
// so that every plot has the sum of plotsizes (total landholding) at each level of the data
bysort y2_hhid: egen totplot=max(landuse_cultivated_ha) 
replace landuse_cultivated_ha=totplot
replace landuse_cultivated_ha=0 if landuse_cultivated==0 
drop totplot 
label var landuse_cultivated_ha "Total area cultivated, ha (ag3a_03)"

*******************INTERCROPPING****************
**ic: intercropped
gen landuse_ic_ap =.
replace landuse_ic_ap = 1 if ag4a_04==1 | ag6a_05 ==1 | ag6b_05 ==1
replace landuse_ic_ap = 0 if ag4a_04==2 | ag6a_05 ==2 | ag6b_05 ==2
label var landuse_ic_ap "Was the plot intercropped"

//Now: can drop observations with no zaocode, because the area for other use has been summed and backfilled to all household observations and the following vars are only for cultivated plots
drop if zaocode ==. //753 obs deleted


********LABOR VARS*********

*Plot number
	*count number of plots (takes a few steps)
encode plotnum, generate(plot_number) // make plotnum numeric
egen nmbr_plots = count(plot_number), by(y2_hhid) 

// obs tagged with 2 or higher means that they are repeat plots (aka have more than one crop on the plot and thus it repeats)
la var nmbr_plots "(plotnum) count of plots by household"
la var plot_number "encode(plotnum) step variable to nmbr_plots"

	*HH Labor - *LRS ONLY*
//Total: all hh labor
drop ag3a_70_id* // drop network id so that we can sum across the variables
egen hh_labor_days = rowtotal(ag3a_70_*) if plot_tag ==1, missing
la var hh_labor_days "(rowtotal ag3a_70) total number of HH labor days on plot - all crops"

*Lists here, run next section all together
local prep ag3a_70_1 ag3a_70_2 ag3a_70_3 ag3a_70_4 ag3a_70_5 ag3a_70_6
local weed ag3a_70_13 ag3a_70_14 ag3a_70_15 ag3a_70_16 ag3a_70_17 ag3a_70_18
local ridge ag3a_70_37 ag3a_70_38 ag3a_70_39 ag3a_70_40 ag3a_70_41 ag3a_70_42
local harvest ag3a_70_25 ag3a_70_26 ag3a_70_27 ag3a_70_28 ag3a_70_29 ag3a_70_30

//HH labor on land preparation/planting
egen hh_prep_days = rowtotal(`prep') if plot_tag ==1, missing
la var hh_prep_days "(rowtotal ag3a_70_1-_6) total number of HH labor days spent on preparation and planting"

//HH labor on weeding
egen hh_weed_days = rowtotal(`weed') if plot_tag ==1, missing
la var hh_weed_days "(rowtotal ag3a_70_13-_18) total number of HH labor days spent on weeding"

//HH labor on ridging and fertilizing
egen hh_ridge_days = rowtotal(`ridge') if plot_tag ==1, missing
la var hh_ridge_days "(rowtotal ag3a_70_37-42) total number of HH labor days spent on ridging and fertilizing"

//HH labor on harvesting
egen hh_harvest_days = rowtotal(`harvest') if plot_tag ==1, missing
la var hh_harvest_days "(rowtotal ag3a_70_25-30) total number of HH labor days spent on harvesting"

**will calculate labor days per hectare after collapse

	*Hired Labor - *LRS ONLY*
*ag3a_71: "Did you hire any labor to work this plot in the LRS 2012?"
local hired_vars ag3a_72_1 ag3a_72_2 ag3a_72_21 ag3a_72_4 ag3a_72_5 ag3a_72_51 ag3a_72_61 ag3a_72_62 ag3a_72_63 ag3a_72_7 ag3a_72_8 ag3a_72_81
egen hired_labor_days = rowtotal(`hired_vars') if ag3a_71==1 & plot_tag ==1, missing
la var hired_labor_days "(ag3a_72) total number of hired labor days"

*Lists here, run next section all together //not sure why the numbering here is nonsensical
local prep1 ag3a_72_1 ag3a_72_2 ag3a_72_21
local weed1 ag3a_72_4 ag3a_72_5 ag3a_72_51
local ridge1 ag3a_72_61 ag3a_72_62 ag3a_72_63
local harvest1 ag3a_72_7 ag3a_72_8 ag3a_72_81

//Hired labor on land prep/planting: total man/woman/child
egen hired_prep_days = rowtotal(`prep1') if plot_tag ==1, missing
la var hired_prep_days "(ag3a_72*) total number of hired labor days spent on preparation and planting"

//Hired labor on weeding: total man/woman/child
egen hired_weed_days = rowtotal(`weed1') if plot_tag ==1, missing
la var hired_weed_days "(ag3a_72*) total number of hired labor days spent on weeding"

//Hired labor on ridging and fertilizing: total man/woman/child
egen hired_ridge_days = rowtotal(`ridge1') if plot_tag ==1, missing
la var hired_ridge_days "(ag3a_72*) total number of hired labor days spent on ridging and fertilizing"

//Hired labor on harvesting: total man/woman/child
egen hired_harvest_days = rowtotal(`harvest1') if plot_tag ==1, missing
la var hired_harvest_days "(ag3a_72*) total number of hired labor days spent on harvesting"

*Check for any unrealistic reporting
sum ag3a_70* ag3a_72* //all are under 100 days except ag3a_74_1, someone reported 330 hired women days for land prep, other large numbers are wage maximums

*Make variables for the other data we want to keep, fill in just once per plot so we can sum to HH
gen hired_women_days_prep = ag3a_72_1 if plot_tag ==1
gen hired_men_days_prep = ag3a_72_1 if plot_tag ==1
gen hired_child_days_prep =  ag3a_72_21 if plot_tag ==1
gen hired_women_days_weed = ag3a_72_4 if plot_tag ==1
gen hired_men_days_weed = ag3a_72_5 if plot_tag ==1
gen hired_child_days_weed = ag3a_72_51 if plot_tag ==1
gen hired_women_days_ridge = ag3a_72_62 if plot_tag ==1
gen hired_men_days_ridge = ag3a_72_61 if plot_tag ==1
gen hired_child_days_ridge = ag3a_72_63 if plot_tag ==1
gen hired_women_days_harv = ag3a_72_7 if plot_tag ==1
gen hired_men_days_harv = ag3a_72_8 if plot_tag ==1
gen hired_child_days_harv = ag3a_72_81 if plot_tag ==1

la var hired_women_days_prep "(ag3a_72_1) total number of hired women days spent on preparation and planting"
la var hired_men_days_prep "(ag3a_72_1) total number of hired men days spent on preparation and planting"
la var hired_child_days_prep "(ag3a_72_21) total number of hired child days spent on preparation and planting"
la var hired_women_days_weed "(ag3a_72_4) total number of hired women days spent on weeding"
la var hired_men_days_weed "(ag3a_72_5) total number of hired men days spent on weeding"
la var hired_child_days_weed "(ag3a_72_51) total number of hired child days spent on weeding"
la var hired_women_days_ridge "(ag3a_72_62) total number of hired women days spent on ridging and fertilizing"
la var hired_men_days_ridge "(ag3a_72_61) total number of hired men days spent on ridging and fertilizing"
la var hired_child_days_ridge "(ag3a_72_63) total number of hired child days spent on ridging and fertilizing"
la var hired_women_days_harv "(ag3a_72_7) total number of hired women days spent on harvesting"
la var hired_men_days_harv "(ag3a_72_8) total number of hired men days spent on harvesting"
la var hired_child_days_harv "(ag3a_72_81) total number of hired child days spent on harvesting"

//replace with zeros if they answered they didn't hire any labor on the plot 
local hiredvars hired_* 
foreach x of varlist `hiredvars' {
replace `x' = 0 if ag3a_71 == 2
} 


//Bysort by household so we can use a max collapse - use a loop. Note: using TOTAL instead of SUM because TOTAL allows the missing option
local laborvars hh_labor_days hh_prep_days hh_weed_days hh_ridge_days hh_harvest_days hired_* 

foreach x of varlist `laborvars' {
	egen tot_`x' = total(`x') if plot_tag==1, by(y2_hhid) missing
bysort y2_hhid: egen totplot=max(tot_`x') 
replace tot_`x'=totplot 
drop totplot 
	}


******************AREA PLANTED*******************

*ag4a_01 "Was crop planted in entire area of plot?"
*ag4a_02 "Approx how much of the plot was planted with [crop]? 1/4, 1/2, 3/4"

*recode to get numeric values and make step variable for crops planted on less than 100% of the plot:
recode ag4a_02 (1=.25) (2=.5) (3=.75)
gen arpl_portion_ha= ag4a_02*plot_area
la var arpl_portion_ha "(ag4a_02 plot_area) portion of annual crop area planted in hectares (step variable to area_planted_ha)"

gen area_planted_ha = .
replace area_planted_ha = plot_area if ag4a_01==1
replace area_planted_ha = arpl_portion_ha if ag4a_01==2

assert arpl_portion_ha==. if ag4a_01==1 // recheck assertion - means all obs either planted whole plot OR planted a portion
la var area_planted_ha "(ag4a_01-02 plot_area) annual crop area planted in hectares (gps if available, else FR)"

*************AREA HARVESTED********************
//annual crops
*ag4a_15 "What was the quantity harvested?(KGs)"
gen harv_quant_kg = .
replace harv_quant_kg = ag4a_15
replace harv_quant_kg = 0 if ag4a_06==2 & ag4a_07==3 //replace with zero if they didn't harvest any crop due to destruction
label var harv_quant_kg "(ag4a_15) Harvested Quantity(KGs), LRS_2010"

*ag4a_16 "What is the estimated value of the harvest crop? (TZ_Shillings)"
gen harv_value_tsh = .
replace harv_value_tsh = ag4a_16
label var harv_value_tsh "(ag4a_16) Value of Harvested Crop (Tz_Shillings), LRS_2010"

*ag4a_08 "What was the area harvested in the LRS 2010?"
*replace with zero if answered no to ag4a_06: "Did you harvest any [crop] on this plot in LRS 2010"
* AND ag4a_07 "Why didn't you harvest any [crop] on this plot" 1. not mine, 2. still in plot, 3. destruction, 4. other
* NOTE: We are only converting to zero if they didn't harvest due to DESTRUCTION (CODE=3)
gen area_harvested_ac = ag4a_08
replace area_harvested_ac =0 if ag4a_06==2 & ag4a_07==3
la var area_harvested_ac "(ag4a_06-08) area harvested in acres, farmer report, capped at plot_area"

*convert to hectares
gen area_harvested_ha = .
replace area_harvested_ha = area_harvested_ac* 0.404685642

*cap area harvested at plotsize if reported area harvested was over GPS plotsize
replace area_harvested_ha = plot_area if area_harvested_ha > plot_area & area_harvested_ha !=. //1403 changes
la var area_harvested_ha "(ag4a_06-08) area harvested in hectares, farmer report, capped at plot_area"

//fruits
gen grew_fruit = 0
replace grew_fruit = 1 if ag6a_02 !=. //if they had at least one fruit tree
la var grew_fruit "household grew any fruit crops in 2010 (ag6a_02)"

gen number_fruits = ag6a_02
la var number_fruits "number of plants/trees on the plot (ag6a_02)"

gen number_fruits_12months = ag6a_04
la var number_fruits_12months "number of trees/plants planted in last 12 months (ag6a_04)"

gen harvest_quant_fruit = ag6a_08
la var harvest_quant_fruit "total amount of fruit harvested (ag6a_08)"

//permanent crops
gen grew_perm = 0
replace grew_perm = 1 if ag6b_02 !=. //if they had at least one permanent crop plant
la var grew_perm "household grew any permanent crops in 2010 (ag6b_02)"

gen number_perm = ag6b_02
la var number_perm "number of plants/trees on the plot (ag6b_02)"

gen number_perm_12months = ag6b_04
la var number_perm_12months "number of trees/plants planted in last 12 months (ag6b_04)"

gen harvest_quant_perm = ag6b_08
la var harvest_quant_perm "total amount of permanent crop harvested (ag6b_08)"


********MAKE VARIABLES THAT SUM ALLOCATION BY CROP //this is unnecessary because now that coding errors have been corrected, the collapse IS working to sum up area (although rounding is slightly different).
//However, we have based all our analysis variables and descriptives on these variables, so it will be easier not to delete them. 

//this will be for permanent/fruit crops with no area planted
egen crop_allocation = sum(plot_area) if plot_area!=., by(y2_hhid zaocode)
bysort y2_hhid zaocode: egen totplot=max(crop_allocation) 
replace crop_allocation=totplot 
drop totplot

//this will be for annual crops
egen arpl_crop = sum(area_planted_ha) if area_planted_ha!=., by(y2_hhid zaocode)
bysort y2_hhid zaocode: egen totplot=max(arpl_crop) 
replace arpl_crop =totplot 
drop totplot 

egen harv_quant_annual_crop = sum(harv_quant_kg) if harv_quant_kg!=., by(y2_hhid zaocode)
bysort y2_hhid zaocode: egen totplot=max(harv_quant_annual_crop) 
replace harv_quant_annual_crop =totplot 
drop totplot

egen harv_quant_perm_crop = sum(harvest_quant_perm) if harvest_quant_perm!=., by(y2_hhid zaocode)
bysort y2_hhid zaocode: egen totplot=max(harv_quant_perm_crop) 
replace harv_quant_perm_crop =totplot 
drop totplot 

egen harv_quant_fruit_crop = sum(harvest_quant_fruit) if harvest_quant_fruit!=., by(y2_hhid zaocode)
bysort y2_hhid zaocode: egen totplot=max(harv_quant_fruit_crop) 
replace harv_quant_fruit_crop =totplot 
drop totplot 

egen arhv_crop = sum(area_harvested_ha) if area_harvested_ha!=., by(y2_hhid zaocode)
bysort y2_hhid zaocode: egen totplot=max(arhv_crop) 
replace arhv_crop =totplot 
drop totplot 

la var crop_allocation "sum of all plot area for crop, by household (arpl, gps if available, else FR)"
la var arpl_crop "sum of total area planted for annual crop, by household (gps if available, else FR)"
la var harv_quant_annual_crop "sum of harvest quantity for annual crop, by household"
la var harv_quant_perm_crop "sum of harvest quantity for permanent crop, by household"
la var harv_quant_fruit_crop "sum of harvest quantity for fruit crop, by household"
la var arhv_crop "sum of area harvested for annual crop, by household (farmer report capped at plotsize)"

count if crop_allocation > sum_plot_area & crop_allocation !=. //0
count if arpl_crop > sum_plot_area & arpl_crop !=.  //0
isid y2_hhid plotnum zaocode, missok //ok

**if you want to preserve more variables, add them to these local lists
local countcollapse plot_cultivated
local maxcollapse grew_fruit grew_perm grew_annual crop_allocation sum_plot_area arpl_crop ///
harv_quant_annual_crop harv_quant_fruit_crop harv_quant_perm_crop arhv_crop ///
landuse_cultivated_ha tot_* nmbr_plots /// 
landuse_ic_ap soil_type soil_quality plot_irrigated org_fert inorg_fert pest_herb_usage 

local sumcollapse plot_area harv_value_tsh  number_fruits number_fruits_12months number_perm number_perm_12months ///
area_planted_ha harv_quant_kg area_harvested_ha harvest_quant_fruit harvest_quant_perm fr_hh 

collapse (count) `countcollapse' (max) `maxcollapse' (sum) `sumcollapse', by (y2_hhid zaocode) 

//label variables
la var area_planted_ha "(ag4a_01-02 plot_area) crop area planted in hectares (gps if available, else FR)"
la var harv_quant_kg "(ag4a_15) Harvested Quantity(KGs), LRS_2010"
la var harv_value_tsh "(ag4a_16) Value of Harvested Crop (Tz_Shillings), LRS_2010"
la var area_harvested_ha "(ag4a_06-08) area harvested in hectares, farmer report, capped at plot_area"
la var number_fruits "number of plants/trees on the plot (ag6a_02)"
la var number_fruits_12months "number of trees/plants planted in last 12 months (ag6a_04)"
la var harvest_quant_fruit "total amount of fruit harvested (ag6a_08)"
la var number_perm "number of plants/trees on the plot (ag6b_02)"
la var number_perm_12months "number of trees/plants planted in last 12 months (ag6b_04)"
la var harvest_quant_perm "total amount of permanent crop harvested (ag6b_08)"
la var grew_fruit "household grew any fruit crops in 2010 (ag6a_02)"
la var grew_perm "household grew any permanent crops in 2010 (ag6b_02)"
la var grew_annual "hh grew annual crops in 2010 (answered section 4)"
la var plot_cultivated "number of plots of this crop cultivated by household during LRS 2010 (ag3a_38)"
la var sum_plot_area "sum of all HH plots in ha LRS 2010 - GPS-based if available, else farmer-report"
la var crop_allocation "sum of all plot area for crop, by household (arpl, gps if available, else FR)"
la var arpl_crop "sum of total area planted for annual crop, by hh (gps if available, else FR)"
la var harv_quant_annual_crop "sum of harvest quantity for annual crop, by household"
la var arhv_crop "sum of area harvested for annual crop, by hh (farmer report cap at plotsize)"
la var landuse_cultivated_ha "Total area cultivated, ha (ag3a_03)" 
la var fr_hh "number of plots without a GPS measure (farmer-reported area used)"
la var nmbr_plots "(plotnum) count of plots by household"
la var tot_hired_women_days_prep "(ag3a_72_1) total number of hired women days spent on prep and planting"
la var tot_hired_men_days_prep "(ag3a_72_1) total number of hired men days spent on prep and planting"
la var tot_hired_child_days_prep "(ag3a_72_21) total number of hired child days spent on prep and planting"
la var tot_hired_women_days_weed "(ag3a_72_4) total number of hired women days spent on weeding"
la var tot_hired_men_days_weed "(ag3a_72_5) total number of hired men days spent on weeding"
la var tot_hired_child_days_weed "(ag3a_72_51) total number of hired child days spent on weeding"
la var tot_hired_women_days_ridge "(ag3a_72_62) total number of hired women days spent on ridging and fertilizing"
la var tot_hired_men_days_ridge "(ag3a_72_61) total number of hired men days spent on ridging and fertilizing"
la var tot_hired_child_days_ridge "(ag3a_72_63) total number of hired child days spent on ridging and fertilizing"
la var tot_hired_women_days_harv "(ag3a_72_7) total number of hired women days spent on harvesting"
la var tot_hired_men_days_harv "(ag3a_72_8) total number of hired men days spent on harvesting"
la var tot_hired_child_days_harv "(ag3a_72_81) total number of hired child days spent on harvesting"
la var tot_hired_labor_days "(ag3a_72) total number of hired labor days"
la var tot_hired_prep_days "(ag3a_72*) total number of hired labor days spent on preparation and planting"
la var tot_hired_weed_days "(ag3a_72*) total number of hired labor days spent on weeding"
la var tot_hired_ridge_days "(ag3a_72*) total number of hired labor days spent on ridging and fertilizing"
la var tot_hired_harvest_days "(ag3a_72*) total number of hired labor days spent on harvesting"
la var tot_hh_labor_days "(rowtotal ag3a_70) total number of HH labor days on plot - all crops"
la var tot_hh_prep_days "(rowtotal ag3a_70_1-_6) total number of HH labor days spent on prep and planting"
la var tot_hh_weed_days "(rowtotal ag3a_70_13-_18) total number of HH labor days spent on weeding"
la var tot_hh_ridge_days "(rowtotal ag3a_70_37-42) total number of HH labor days spent on ridging and fertilizing"
la var tot_hh_harvest_days "(rowtotal ag3a_70_25-30) total number of HH labor days spent on harvesting"
label var landuse_ic_ap "Dummy if plot cultivated is intercropped, all crops"
label var soil_type "(ag3a_09) Type of soil on the plot, 1=sandy, 2=loam, 3=clay, 4=other"
label var soil_quality "(ag3a_10) Soil quality on the plot, 1=good, 2=average, 3=bad"
label var plot_irrigated "(ag3a_17) Dummy if plot was irrigated"
label var org_fert "(ag3a_39) Dummy if used organic fertilizer"
label var inorg_fert "(ag3a_45) Dummy if used inorganic fertilizer"

count if crop_allocation > sum_plot_area & crop_allocation !=. //0
count if arpl_crop > sum_plot_area & arpl_crop !=. //0 

save "$collapse/plot_to_crop_hh.dta", replace


//////////////////////////////////////////////////////////////////////////////////////////////////////////////
*************************** Merge IN OTHER DATASETS & Match Variables **************************************** 
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

**Merge in Section 5A 2010 LRS -- HH-crop-level dataset. 
merge m:1 y2_hhid zaocode using "$input\AG_SEC5A", keep (1 3) gen (_merge_SEC5A_2010)
*4617 matched 
*7398 not matched from master //they only report on 4 crops, so these are probably additional crops per HH (or have no zaocode)

**add in 7A: Fruit crops total
merge m:1 y2_hhid zaocode using "$input\AG_SEC7A", keep (1 3) gen (_merge_fruit_total) 
*4108 matched, 7907 not matched from master

**add in 7B: Permanent crops total
merge m:1 y2_hhid zaocode using "$collapse\AG_SEC7B_prepped.dta", keep (1 3) gen (_merge_perm_total) //note these will not match to the obs with changed zaocodes
*2978 matched, 9037 not matched from master

**Merge in maize consumption
merge m:1 y2_hhid using "$collapse/HH_SEC_K1_maize_consumption.dta", keep (1 3) gen (_merge_maizecons)
*12015 matched

**Merge in Household Data Set - Collapsed at the Household Level
merge m:1 y2_hhid using "$collapse\HH_merge.dta", keep (1 3) gen (_merge_HHDATA_Collapsed)
*Matched: 12015
*Not Matched: 0

**Merge in Consumption Data Set - Taken Directly from Raw Data
merge m:1 y2_hhid using "$input\TZY2.HH.Consumption.dta"  , keep (1 3) gen (_merge_HHConsumption_2010)
*Matched: 11846
*Not Matched from master: 169

**Merge in Geovariables
merge m:1 y2_hhid using "$input\TZY2_HHGeovariables.dta" , keep (1 3) gen (_merge_hh_geo)
*12015 matched

**Merge in survey weights
merge m:1 y2_hhid using "$input\HH_SEC_A.dta", keep (1 3) gen (_merge_weights)
*12015 matched

//Drop non-ag HH
drop if  zaocode ==. //0

codebook y2_hhid //2535 cultivating hh will be in our analysis
isid y2_hhid zaocode //ok

//////////////////RENAME VARIABLES TO MATCH OTHER WAVES, add _2010

///////////////////////MATCH 2008-2010 Variables//////////////////////////

rename ag5a_13 ag5a_13_x
rename ag5a_18 ag5a_18_x
rename ag5a_19 ag5a_19_x
rename ag5a_20 ag5a_20_x
rename ag5a_21 ag5a_21_x
rename ag5a_22 ag5a_22_x
rename ag5a_29 ag5a_29_x
rename ag5a_30 ag5a_30_x
rename ag5a_31 ag5a_31_x
rename ag5a_32 ag5a_32_x
rename ag5a_24 ag5a_24_x
rename ag5a_25 ag5a_25_x
rename ag5a_26 ag5a_26_x
rename ag7a_13 ag7a_13_x
rename ag7a_14 ag7a_14_x
**relabel these variables later to indicate that they have been renamed

*loop to match and rename variables
*create local lists for 2010 (z) variables and 2012 (x) variables
local vars2010 ag5a_01 ag5a_02 ag5a_03 ag5a_04_1 ag5a_05 ag5a_06 ag5a_10 ag5a_11 ag5a_15 ag5a_16 ag5a_17 ag5a_18 ag5a_19 ag5a_20 ag5a_21 ag5a_22 ag5a_23 ag5a_28 ag5a_29 ag5a_30 ag5a_31 /*
*/ ag5a_32 ag5a_33 fisherb2c2 intmonth intyear hh_clim01 hh_clim02 hh_clim03 hh_clim04 hh_clim05 hh_clim06 hh_clim07 hh_clim08 hh_clim09 hh_envi01 /*
*/ hh_envi02 hh_envi03 hh_envi04 hh_envi05 hh_envi06 hh_envi07 hh_envi08 hh_envi09 hh_envi10 hh_envi11 hh_envi12 hh_envi13 hh_envi14 hh_geo01 hh_geo02 /*
*/ hh_geo03 hh_geo04 hh_geo05 hh_geo06 hh_soil_con01 hh_soil_con02 hh_soil_con03 hh_soil_con04 hh_soil_con05 hh_soil_con06 hh_soil_con07 district /*
*/ ward y2_rural hh_a20 hh_a23 hh_a16 ag7a_02 ag7a_03 ag7a_04 ag7a_05_1 ag7a_05_2 ag7a_06 ag7a_07 ag7a_08 ag7a_09 ag7a_10 ag7a_11 ag7a_12 ag7a_13 ag7a_14


local vars2012 ag5a_01 ag5a_02 ag5a_03 ag5a_04 ag5a_05 ag5a_06 ag5a_12 ag5a_13 ag5a_18 ag5a_19 ag5a_20 ag5a_21 ag5a_22 ag5a_29 ag5a_30 ag5a_31 ag5a_32 ag5a_23 /*
*/ ag5a_24 ag5a_25 ag5a_26 ag5a_27 ag5a_28 fisherb3c3 hh_a18_2 hh_a18_3 crops01 crops02 crops03 crops04 crops05 crops06 crops07 crops08 crops09 clim01 /*
*/ clim02 clim03 clim04 clim05 crops10 crops11 crops12 crops13 crops14 crops15 crops16 crops17 crops18 dist01 dist02 dist03 dist05 dist04 plot03 soil05 /*
*/ soil06 soil07 soil08 soil09 soil10 soil11 plot01 hh_a02_1  hh_a03_1 y3_rural hh_a20 hh_a23 hh_a16 ag7a_02 ag7a_03 ag7a_04 ag7a_07_1 ag7a_07_2 /*
*/ ag7a_13 ag7a_14 ag7a_15 ag7a_16 ag7a_08 ag7a_09 ag7a_10 ag7a_11 ag7a_12


**This is the correct code do not change or delete!!!!!!!!!!!!!
local n : word count `vars2010'
*run loop 
forvalues i=1/`n'{
*set x and y to var order
local z : word `i' of `vars2010'
local x : word `i' of `vars2012'
*add label to panel variable
rename (`z') (`x')
}


**add _2010 to the end
foreach x of varlist *{
rename `x' `x'_2010
}

//reversing these renames, because we need to merge on them
rename zaocode_2010 zaocode
rename y2_hhid_2010 y2_hhid

gen hhid_p = y2_hhid
la var hhid_p "unique panel identifier"

gen wave2 =1
la var  wave2 "observation existed in wave 2"
isid hhid_p zaocode


**Now we will create an identifier for whether a household experienced a split-off between 2010 and 2012. 

//make a dummy var equal to 1 if hh was a "child" splitoff 
gen splitoff_child_2010 =.
replace splitoff_child_2010 =1 if hh_a11_2010 ==3
replace splitoff_child_2010 =0 if hh_a11_2010 <3
la var splitoff_child_2010 "hh is a 'child' splitoff (hh_a11)"

//make a dummy var equal to 1 if hh experienced a split since 2008 (is either "parent" or "child" hh), equal to 0 ONLY if it did not split
*hhid_2008 is only filled in for original households, so we need to make a variable we can sort by that reflects this for everyone - by taking the last two digits off y2_hhid
//now make a variable equal to the first 14 digits of y2_hhid, which indicate if the hh was a splitoff 
gen string2010 = substr(y2_hhid, 1,14) //(equal to y2_hhid, starting at the beginning and keeping the next 14 digits)
*br string2010 hhid_2008
la var string2010 "2008 hh identifier for ALL households, including splitoffs (y2_hhid, without last two digits)"

*string2010 has 2008 HHIDs for ALL households, not just original households - we will sort by that
egen experienced_splitoff_2010 = max(splitoff_child_2010), by(string2010)
la var experienced_splitoff_2010 "hh experienced splitoff between 2008 and 2010 - original OR child (hh_a11)"

//make a dummy that identifies the "parent" hh that experienced a split only
gen splitoff_parent_2010 =.
replace splitoff_parent_2010 =1 if experienced_splitoff_2010 ==1 & splitoff_child_2010 ==0 
replace splitoff_parent_2010 =0 if experienced_splitoff_2010 ==0 
replace splitoff_parent_2010 =0 if splitoff_child_2010 ==1
la var splitoff_parent_2010 "hh is a 'parent' that experienced a split (hh_a11)"

codebook y2_hhid if splitoff_child_2010 ==1 //390
codebook y2_hhid if splitoff_parent_2010 ==1 //255
codebook y2_hhid if experienced_splitoff_2010 ==0 //1889
display 390+255+1889 //2534
codebook y2_hhid //2535. One hh, 0901016002024201, is missing data for hh_a11. However, ID ends in 01, so it is not a splitoff. 
*br if string2010 == "09010160020242" //These are the only obs for this hhid_2008, so this is an ORIGINAL hh. Manually replace. 
replace experienced_splitoff_2010 =0 if y2_hhid =="0901016002024201" //4 changes
replace splitoff_parent_2010 =0 if y2_hhid =="0901016002024201"
replace splitoff_child_2010 =0 if y2_hhid =="0901016002024201"

//make a dummy for ORIGINAL HH in new location from 2008-2010 -- we don't know this about splitoffs in this wave
gen hh_moved_2010 = .
replace hh_moved_2010 =0 if hh_a11_2010 ==1
replace hh_moved_2010 =1 if hh_a11_2010 ==2
la var hh_moved_2010 "ORIGINAL household moved between 2008 and 2010 (hh_a11)"

isid y2_hhid zaocode

save "$output/W2_merged_shiny.dta", replace 

