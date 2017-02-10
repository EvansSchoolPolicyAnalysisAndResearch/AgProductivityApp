*Title/Purpose of Do File: Tanzania LSMS-ISA W3(2012-13) - Ag survey - Prepare data for Shiny agricultural productivity app
*Unique identifiers (level): y3_hhid zaocode
*Author(s): Katie Panhorst Harris, Maggie Beetstra
*Date started: 11/27/15
*Date completed: 8/8/16

*CHECKED BY: Melissa LaFayette, 12/9/15
*Checked by: David Coomes, 1/21/17

*This file to be run before Three-panel_merge and W1-3_Cluster_Prices

/////////////HIERARCHY////////////////////////////
*y3_hhid - unique HH identifier 
**(indidy1) - can use to merge with panel key
**plotnum (within hh) - this merges in ag data at plot level


//SET DIRECTORIES - make sure to reset these
clear
global input "FILEPATH" //Reset to where you have downloaded the raw data 
global merge "FILEPATH\Merged Data Shiny" //set up an output folder to save .dtas to use in the panel merge, reset 
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
use "$input\Household\HH_SEC_J1"

**Generating variables
gen cons_tot_greenmaize_kg =.
replace cons_tot_greenmaize_kg = hh_j02_2 if hh_j02_1 == 1 & itemcode == 0103
replace cons_tot_greenmaize_kg = hh_j02_2/1000 if hh_j02_1 == 2 & itemcode == 0103
replace cons_tot_greenmaize_kg = 0 if hh_j01 == 2 & itemcode ==0103

gen cons_tot_maizegrain_kg =.
replace cons_tot_maizegrain_kg = hh_j02_2 if hh_j02_1 == 1 & itemcode == 0104
replace cons_tot_maizegrain_kg = hh_j02_2/1000 if hh_j02_1 == 2 & itemcode == 0104
replace cons_tot_maizegrain_kg = 0 if hh_j01 == 2 & itemcode ==0104

gen cons_tot_maizeflour_kg =.
replace cons_tot_maizeflour_kg = hh_j02_2 if hh_j02_1 == 1 & itemcode == 0105
replace cons_tot_maizeflour_kg = hh_j02_2/1000 if hh_j02_1 == 2 & itemcode == 0105
replace cons_tot_maizeflour_kg = 0 if hh_j01 == 2 & itemcode ==0105

gen cons_own_greenmaize_kg =0
replace cons_own_greenmaize_kg = hh_j05_2 if hh_j05_1 == 1 & itemcode == 0103
replace cons_own_greenmaize_kg = hh_j05_2/1000 if hh_j05_1 == 2 & itemcode == 0103

gen cons_own_maizegrain_kg =0
replace cons_own_maizegrain_kg = hh_j05_2 if hh_j05_1 == 1 & itemcode == 0104
replace cons_own_maizegrain_kg = hh_j05_2/1000 if hh_j05_1 == 2 & itemcode == 0104

gen cons_own_maizeflour_kg =0
replace cons_own_maizeflour_kg = hh_j05_2 if hh_j05_1 == 1 & itemcode == 0105
replace cons_own_maizeflour_kg = hh_j05_2/1000 if hh_j05_1 == 2 & itemcode == 0105

////////////COLLAPSE TO HH LEVEL

local consumption cons_*
collapse (max) `consumption', by (y3_hhid)

la var cons_tot_greenmaize_kg "(hh_j02) total household weekly consumption of green maize, kg"
la var cons_tot_maizegrain_kg "(hh_j02) total household weekly consumption of maize grain, kg"
la var cons_tot_maizeflour_kg "(hh_j02) total household weekly consumption of maize flour, kg"
la var cons_own_greenmaize_kg "(hh_j05) household weekly consumption from own production of green maize, kg"
la var cons_own_maizegrain_kg "(hh_j05) household weekly consumption from own production of maize grain, kg"
la var cons_own_maizeflour_kg "(hh_j05) household weekly consumption from own production of maize flour, kg"


save "$collapse/HH_SEC_J1_maize_consumption.dta", replace

************************************************
///////////HOUSEHOLD SECTION////////////////////
************************************************
*We only need to preserve a few variables from this section: age of HH head, education of HH head, gender of HH head
clear
use "$input\Household\HH_SEC_A"

//Merge in section B: Household Member Roster
**Unaltered .dta file
sort y3_hhid
merge 1:m y3_hhid using "$input\Household\HH_SEC_B", generate (_merge_HH_SEC_B)
//matched: 25,412
//not matched:0

//Merge in section C: Education
**Unaltered .dta file
merge 1:1 y3_hhid indidy3 using "$input\Household\HH_SEC_C", generate(_merge_HH_SEC_C)
//matched: 25,412
//not matched:0

//Generate variable for HH size (note there is an "adult equivalent" hh size number in consumption file)
egen hh_size = count(indidy3), by(y3_hhid) 
la var hh_size "count (indidy3): number of household members"

**136 vars - only keep necessary vars - HH ids and weights, splitoff and location info, Age, edu, sex, HH head 
keep y3_hhid y2_hhid indidy3 clusterid strataid y3_weight hh_size hh_a09 hh_a10 hh_a11 hh_a13 hh_b01 hh_b02 hh_b04 hh_b05 hh_c0* 
isid y3_hhid indidy3
//hh_b05 identifies the HH head. Dropping others
drop if hh_b05!=1
isid y3_hhid
//n=5010 HH

save "$collapse/HH_merge.dta", replace


///////////////////////////////////////////////
///											///
///					MERGING					///
///											///
///////////////////////////////////////////////

****************** PREP PERMANENT AND TREE CROPS (REMOVE DUPLICATES)************************************* 
**6A: fruit crops
clear
use "$input\Agriculture\AG_SEC_6A.dta"
drop if plotnum=="" // 3126 deleted
*isid y3_hhid plotnum zaocode //we have some duplicate crops on the same plot

//now identifying plots with the same crop on plot twice
// use duplicates tag command to find obs that are preventing the unique idenitfier
duplicates tag y3_hhid plotnum zaocode, gen(duptag)
tab duptag // 24 obs duplicates -- preventing a merge!
*br if duptag ==1 //problems are banana, mango, and other crops

sort y3_hhid plotnum zaocode // this code give unique dup identifier 
quietly by y3_hhid plotnum zaocode:  gen dup = cond(_N==1,0,_n)
replace dup=. if dup==1 | dup ==0

//four households have two banana obs on plot. One hh has two mango observations. 
gen zaocode2=. //assign a different zaocode value to duplicates so we can continue to track them if desired
replace zaocode2=899+dup if zaocode==998 & dup!=. //for "other" duplicates 90_
replace zaocode2=1099+dup if zaocode==71 & dup!=. //for banana duplicates 110_
replace zaocode2=1199+dup if zaocode==73 & dup!=. //for mango duplicates 120_

replace zaocode=zaocode2 if dup!=. //replace zaocode value with new zaocode value if it is a duplicate


drop dup duptag //no longer needed

isid y3_hhid plotnum zaocode, missok 
save "$collapse\AG_SEC_6A_prepped.dta", replace

**6B: Permanent crops
clear
use "$input\Agriculture\AG_SEC_6B"
drop if plotnum=="" // 3051 deleted
*isid y3_hhid plotnum zaocode, missok //duplicates
duplicates tag y3_hhid plotnum zaocode, gen(duptag)
tab duptag // lots of duplicates-- preventing a merge!
*br if duptag !=0 

sort y3_hhid plotnum zaocode // this code give unique dup identifier 
quietly by y3_hhid plotnum zaocode:  gen dups = cond(_N==1,0,_n)
replace dups=. if dups==1 | dups ==0
label var dups "zaocode duplicates"

gen zaocode2=.
replace zaocode2=399+dups if zaocode==304 & dups!=. //for timber duplicates: 40_
replace zaocode2=499+dups if zaocode==303 & dups!=. //for firewood/fodder duplicates 50_
replace zaocode2=599+dups if zaocode==21 & dups!=. // for cassava duplicates 60_
replace zaocode2=699+dups if zaocode==45 & dups!=. //for coconut duplicates 70_
replace zaocode2=799+dups if zaocode==46 & dups!=. //for cashew duplicates 80_
replace zaocode2=899+dups if zaocode==998 & dups!=. //for "other" duplicates 90_
replace zaocode2=999+dups if zaocode==54 & dups!=. //for coffee duplicates 100_
label var zaocode2 "new zaocode for duplicates"

replace zaocode=zaocode2 if dups!=. //replace zaocode value with new zaocode value if it is a duplicate

drop dups duptag
isid y3_hhid plotnum zaocode
save "$collapse\AG_SEC_6B_prepped.dta", replace

**7A: Fruit crops
clear
use "$input\Agriculture\AG_SEC_7A"
*isid y3_hhid zaocode, missok
duplicates tag y3_hhid zaocode, gen(duptag)
tab duptag // 17 duplicates-- preventing a merge!
*br if duptag !=0 
drop if zaocode==. //3129 deleted

sort y3_hhid zaocode // this code give unique dup identifier 
quietly by y3_hhid zaocode:  gen dups = cond(_N==1,0,_n)
replace dups=. if dups==1 | dups ==0
label var dups "zaocode duplicates"

gen zaocode2=.
replace zaocode2=899+dups if zaocode==998 & dups!=. //for "other" duplicates 90_
replace zaocode2=1099+dups if zaocode==71 & dups!=. //for banana duplicates 110_

replace zaocode=zaocode2 if dups!=. //replace zaocode value with new zaocode value if it is a duplicate


drop dups duptag //no longer needed

isid y3_hhid zaocode, missok
save "$collapse\AG_SEC_7A_prepped.dta", replace

**7B: Permanent crops
clear 
use "$input\Agriculture\AG_SEC_7B"
*isid y3_hhid zaocode, missok
drop if zaocode==. // 3057 deleted

duplicates tag y3_hhid zaocode, gen(duptag)
tab duptag // a bunch of duplicates-- preventing a merge!
*br if duptag !=0 

sort y3_hhid zaocode // this code give unique dup identifier 
quietly by y3_hhid zaocode:  gen dups = cond(_N==1,0,_n)
replace dups=. if dups==1 | dups ==0
label var dups "zaocode duplicates"

gen zaocode2=.
replace zaocode2=399+dups if zaocode==304 & dups!=. //for timber duplicates: 40_
replace zaocode2=499+dups if zaocode==303 & dups!=. //for firewood/fodder duplicates 50_
replace zaocode2=599+dups if zaocode==21 & dups!=. // for cassava duplicates 60_
replace zaocode2=899+dups if zaocode==998 & dups!=. //for "other" duplicates 90_
replace zaocode2=999+dups if zaocode==54 & dups!=. //for coffee duplicates 100_
label var zaocode2 "new zaocode for duplicates"

replace zaocode=zaocode2 if dups!=. //replace zaocode value with new zaocode value if it is a duplicate


drop dups duptag
isid y3_hhid zaocode, missok
save "$collapse\AG_SEC_7B_prepped.dta", replace

**5A: crops HH totals, LRS 
clear
use "$input\Agriculture\AG_SEC_5A.dta"
//n=8422

*isid y3_hhid zaocode, missok // not a unique id
*Goal: get the unique id to be y3_hhid and zaocode
drop if zaocode==. // 2266 deleted

duplicates tag y3_hhid zaocode, gen(duptag)
tab duptag // 9 duplicates-- preventing a merge!
*br if duptag !=0 

sort y3_hhid zaocode // this code give unique dup identifier
quietly by y3_hhid zaocode:  gen dups = cond(_N==1,0,_n)
replace dups=. if dups==1 | dups ==0
label var dups "zaocode duplicates"

gen zaocode2=.
replace zaocode2=899+dups if zaocode==998 & dups!=. //for "other" duplicates 90_
label var zaocode2 "new zaocode for duplicates"

replace zaocode=zaocode2 if dups!=. //replace zaocode value with new zaocode value if it is a duplicate

drop dups duptag

isid y3_hhid zaocode, missok
save "$collapse\AG_SEC_5A_prepped.dta", replace

///////////////prep plot geovars - there are duplicates so y3_hhid plotnum do not uniquely identify the data
clear
use "$input\PlotGeovars_Y3.dta", clear
//n=5453 HH
duplicates tag y3_hhid plotnum, gen(duptag)
//47 blank obs. will drop
drop if duptag>0 // 47 obs dropped
//n=5406
drop duptag
isid y3_hhid plotnum, missok // unique id
save "$collapse\plot_geovars_prepped", replace


//////////////////////////////////////////////
//											//
//					MERGING					//
//											//
//////////////////////////////////////////////

**********************	CROP LEVEL	*******************************
**First, we will merge all the data at the CROP LEVEL together: annual, permanent, and tree crops. 
**There will be one observation per hhid/plotnum/zaocode. Then afterward we will merge this to the hh/plot level data 
//so that all crop observations are associated with their plot data (doesn't work in reverse order)
**These datasets have duplicate problems (y3_hhid plotnum zaocode do not uniquely identify) so we will deal with them each separately.

**Start with 4A: crops by plots, LRS (annual crops)
clear
use "$input\Agriculture\AG_SEC_4A.dta"
drop if plotnum=="" // 2249 deleted
//n=7934
*isid y3_hhid plotnum zaocode//we have some duplicate crops on the same plot


//now identifying plots with the same crop on plot twice
// use duplicates tag command to find obs that are preventing the unique idenitfier
duplicates tag y3_hhid plotnum zaocode, gen(duptag)
tab duptag // 11 obs duplicates -- preventing a pretty merge!
*br if duptag ==1 | duptag==2 

sort y3_hhid plotnum zaocode // this code give unique dup identifier 
quietly by y3_hhid plotnum zaocode:  gen dups = cond(_N==1,0,_n)
replace dups=. if dups==1 | dups ==0
label var dups "zaocode duplicates"

gen zaocode2=.
//three HHs have 'other' crops planted on same plot (thus cannot uniquely identify) 
replace zaocode2=899+dups if zaocode==998 & dups!=. //for "other" duplicates 90_
replace zaocode2=1299+dups if zaocode==31 & dups!=. //for beans duplicates 130_

replace zaocode=zaocode2 if dups!=. //replace zaocode value with new zaocode value if it is a duplicate

drop dups duptag // no longer needed

isid y3_hhid plotnum zaocode, missok // ok


gen grew_annual = 1
la var grew_annual "hh grew annual crops in 2012 (answered section 4)"

merge 1:1 y3_hhid plotnum zaocode using "$collapse\AG_SEC_6A_prepped.dta", gen (_plot_fruit)
**1 matched (this matched "other" to "other"), 7933 not matched from master (annual crops - won't match with fruit zaocodes), 5668 not matched from using (fruit crops - won't match with annual zaocodes)

**add in 6B: other permanent crops
merge 1:1 y3_hhid plotnum zaocode using "$collapse\AG_SEC_6B_prepped.dta", gen (_plot_perm)
**11 matched (hh reported crop in both fruit AND permanent), 13591 not matched from master (annual and fruit), 4664 not matched from using (permanent)

replace grew_annual = 0 if grew_annual ==.

save "$collapse\crop_level.dta", replace 



***************************************************************************************
************	PLOT LEVEL and PLOT-CROP LEVEL TO HH-CROP LEVEL	   ******************** 
***************************************************************************************

********** PLOT LEVEL DATA *************
//We will begin by merging the plot-level datasets and creating the plot-level variables we need. Afterwards we will merge the plot-crop sections and create the crop-level variables. 
//For this analysis, we will have to collapse to the crop-hh level to merge panels.

**start with 2A: LRS plot numbers (Ms)
clear
use "$input\Agriculture\AG_SEC_2A.dta" 


**add in 3A: LRS plot details
merge 1:1 y3_hhid plotnum using "$input\Agriculture\AG_SEC_3A.dta", gen (_plotLRS_plotdetails)
** 9157 matched, 0 not matched 
isid y3_hhid plotnum,missok // ok

**add in 4A, 6A, and 6B, merged above -- DATASET WILL NOW BE AT CROP LEVEL
merge 1:m y3_hhid plotnum using "$collapse\crop_level.dta", keep (1 3) gen (_plot_crop)
**18255 matched, 2592 not matched from master (must be non-cultivated plots) (unmatched from using are SRS plot numbers - begin with V. We will not keep these since we are not using SRS in our analysis.)

**add in plot geovars
merge m:1 y3_hhid plotnum using "$collapse\plot_geovars_prepped.dta", keep (1 3) gen (_plot_geovars)
// 15612 matched, 5235 not matched from master

// Some HH are missing geovariables, therefore many unmatched from master
// NOTE: This file is at the PLOT-CROP level

*drop if no plot number 
drop if plotnum == ""  //1710 deleted

gen plot_cultivated =1 if ag3a_40==1
replace plot_cultivated =0 if ag3a_40==2
la var plot_cultivated "plot cultivated during LRS 2012 (ag3a_40)"

**************Plot size************
gen plotsize_acres = ag2a_04
la var plotsize_acres "(ag2a_04) farmer reported plot size in acres"

gen plotsize_ha = plotsize_acres* 0.404685642
la var plotsize_acres "(ag2a_04) farmer reported plot size in hectares"

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
egen plot_tag =tag(y3_hhid plotnum) //step var only
la var plot_tag "plot-level tag"

//VARIABLE TO USE: GPS-based if they have one, farmer-report if not
egen sum_plot_area = sum(plot_area) if plot_tag==1 & plot_area!=., by(y3_hhid)
// the code below is needed so that the number of plots fills in by y3_hhid (run piece by piece if unclear)
// in otherwords, egen above will create missings for duplicate plots and we want those missings to fill in with the value
// so that every plot has the sum of plotsizes (total landholding) at each level of the data
bysort y3_hhid: egen totplot=max(sum_plot_area) 
replace sum_plot_area=totplot // tell it to back fill so that missings are changed to the number of plots
drop totplot // don't need it
la var sum_plot_area "sum(plot_area) sum of all HH plots in ha LRS 2012 - GPS-based if they have one, farmer-report if not"

**********************SOIL************************
//looking at soil type and soil quality
rename ag3a_10 soil_type
label var soil_type "Soil type of the plot"
rename ag3a_11 soil_quality
label var soil_quality "Soil quality of the plot"

*******************FERTILIZER*********************
gen org_fert=.
replace org_fert = 1 if ag3a_41==1
replace org_fert = 0 if ag3a_41==2
label var org_fert "Organic fertilizer used on plot"

gen inorg_fert=.
replace inorg_fert = 1 if ag3a_47==1
replace inorg_fert = 0 if ag3a_47==2
label var inorg_fert "Inorganic fertilizer used on plot"

***************PESTICIDE/HERBICIDE****************
gen pest_herb_usage=.
replace pest_herb_usage = 1 if ag3a_60==1
replace pest_herb_usage = 0 if ag3a_60==2
label var pest_herb_usage "Any pesticide/herbicide used on plot"

*******************IRRIGATION************************	
gen plot_irrigated =.
replace plot_irrigated=1 if ag3a_18 == 1
replace plot_irrigated=0 if ag3a_18 == 2
la var plot_irrigated "(ag3a_18) Plot irrigated in LRS 2012"


********************PLOT USE********************** ALL BASED ON plot_area
//goal to figure out the amount of land (plots summed) and then determine how much of that land is used for each purpose

**if a household has a plot that is cultivated, then keep it and divide the cultivated area by the total landholding area
**identify which plots are cultivated
gen landuse_cultivated=.
replace landuse_cultivated = 1 if ag3a_03==1
**ag3a_03!=. below keeps that missings as missing
replace landuse_cultivated = 0 if ag3a_03!=1 & ag3a_03!=.
label var landuse_cultivated "Did you cultivate this plot, section 3 of ag survey"
**take those plots and find their area - all other plots should be 0 or .
egen landuse_cultivated_ha = sum(plot_area) if landuse_cultivated ==1 & plot_tag==1 & plot_area!=., by(y3_hhid)
bysort y3_hhid: egen totplot=max(landuse_cultivated_ha) 
replace landuse_cultivated_ha=totplot
replace landuse_cultivated_ha=0 if landuse_cultivated==0 
replace landuse_cultivated_ha=. if landuse_cultivated==. 
drop totplot 
label var landuse_cultivated_ha "Total area cultivated, ha (ag3a_03)"

*******************INTERCROPPING*****************
gen landuse_ic_ap =.
replace landuse_ic_ap = 1 if ag4a_04==1 | ag6a_05 ==1 | ag6b_05 ==1
replace landuse_ic_ap = 0 if ag4a_04==2 | ag6a_05 ==2 | ag6b_05 ==2
label var landuse_ic_ap "Was the plot intercropped"


********LABOR VARS********* 

*Plot number

	*count number of plots (takes a few steps)
encode plotnum, generate(plot_number) // make plotnum numeric

egen nmbr_plots = count(plot_number), by(y3_hhid) 

// obs tagged with 2 or higher means that they are repeat plots (aka have more than one crop on the plot and thus it repeats)
la var nmbr_plots "(plotnum) count of plots by household"
la var plot_number "encode(plotnum) step variable to nmbr_plots"

	*HH Labor - *LRS ONLY*
//Total: all hh labor
drop ag3a_72_id* ag3a_72_25 ag3a_72_26 ag3a_72_27 ag3a_72_28 // drop network id and hours spent so that we can sum across the variables
egen hh_labor_days = rowtotal(ag3a_72_*) if plot_tag ==1, missing
la var hh_labor_days "(rowtotal ag3a_72) total number of HH labor days on plot - all crops"

*Lists here, run next section all together
local prep ag3a_72_1 ag3a_72_2 ag3a_72_3 ag3a_72_4 ag3a_72_5 ag3a_72_6
local weed ag3a_72_7 ag3a_72_8 ag3a_72_9 ag3a_72_10 ag3a_72_11 ag3a_72_12
local ridge ag3a_72_13 ag3a_72_14 ag3a_72_15 ag3a_72_16 ag3a_72_17 ag3a_72_18
local harvest ag3a_72_19 ag3a_72_20 ag3a_72_21 ag3a_72_22 ag3a_72_23 ag3a_72_24

//HH labor on land preparation/planting
egen hh_prep_days = rowtotal(`prep') if plot_tag ==1, missing
la var hh_prep_days "(rowtotal ag3a_72_1-_6) total number of HH labor days spent on preparation and planting"

//HH labor on weeding
egen hh_weed_days = rowtotal(`weed') if plot_tag ==1, missing
la var hh_weed_days "(rowtotal ag3a_72_7-_12) total number of HH labor days spent on weeding"

//HH labor on ridging and fertilizing
egen hh_ridge_days = rowtotal(`ridge') if plot_tag ==1, missing
la var hh_ridge_days "(rowtotal ag3a_72_13-_18) total number of HH labor days spent on ridging and fertilizing"

//HH labor on harvesting
egen hh_harvest_days = rowtotal(`harvest') if plot_tag ==1, missing
la var hh_harvest_days "(rowtotal ag3a_72_19-_24) total number of HH labor days spent on harvesting"

**will calculate labor days per hectare after collapse

	*Hired Labor
*ag3a_73: "Did you hire any labor to work this plot in the LRS 2012?"
local hired_vars ag3a_74_1 ag3a_74_2 ag3a_74_3 ag3a_74_5 ag3a_74_6 ag3a_74_7 ag3a_74_9 ag3a_74_10 ag3a_74_11 ag3a_74_13 ag3a_74_14 ag3a_74_15
egen hired_labor_days = rowtotal(`hired_vars') if ag3a_73==1 & plot_tag ==1, missing
la var hired_labor_days "(ag3a_74) total number of hired labor days"

*Lists here, run next section all together
local prep1 ag3a_74_1 ag3a_74_2 ag3a_74_3
local weed1 ag3a_74_5 ag3a_74_6 ag3a_74_7
local ridge1 ag3a_74_9 ag3a_74_10 ag3a_74_11
local harvest1 ag3a_74_13 ag3a_74_14 ag3a_74_15

//Hired labor on land prep/planting: total man/woman/child
egen hired_prep_days = rowtotal(`prep1') if plot_tag ==1, missing
la var hired_prep_days "(rowtotal ag3a_74_1-_3) total number of hired labor days spent on preparation and planting"

//Hired labor on weeding: total man/woman/child
egen hired_weed_days = rowtotal(`weed1') if plot_tag ==1, missing
la var hired_weed_days "(rowtotal ag3a_74_5-_7) total number of hired labor days spent on weeding"

//Hired labor on ridging and fertilizing: total man/woman/child
egen hired_ridge_days = rowtotal(`ridge1') if plot_tag ==1, missing
la var hired_ridge_days "(rowtotal ag3a_74_9-_11) total number of hired labor days spent on ridging and fertilizing"

//Hired labor on harvesting: total man/woman/child
egen hired_harvest_days = rowtotal(`harvest1') if plot_tag ==1, missing
la var hired_harvest_days "(rowtotal ag3a_74_13-_15) total number of hired labor days spent on harvesting"

*Check for any unrealistic reporting
sum ag3a_72* ag3a_74* //all are under 100 days except ag3a_74_1, someone reported 330 hired women days for land prep, other large numbers are wage maximums

*Make variables for the other data we want to keep, fill in just once per plot so we can sum to HH
gen hired_women_days_prep = ag3a_74_1 if plot_tag ==1
gen hired_men_days_prep = ag3a_74_2 if plot_tag ==1
gen hired_child_days_prep =  ag3a_74_3 if plot_tag ==1
gen hired_women_days_weed = ag3a_74_5 if plot_tag ==1
gen hired_men_days_weed = ag3a_74_6 if plot_tag ==1
gen hired_child_days_weed = ag3a_74_7 if plot_tag ==1
gen hired_women_days_ridge = ag3a_74_9 if plot_tag ==1
gen hired_men_days_ridge = ag3a_74_10 if plot_tag ==1
gen hired_child_days_ridge = ag3a_74_11 if plot_tag ==1
gen hired_women_days_harv = ag3a_74_13 if plot_tag ==1
gen hired_men_days_harv = ag3a_74_14 if plot_tag ==1
gen hired_child_days_harv = ag3a_74_15 if plot_tag ==1

la var hired_women_days_prep "(ag3a_74_1) total number of hired women days spent on preparation and planting"
la var hired_men_days_prep "(ag3a_74_2) total number of hired men days spent on preparation and planting"
la var hired_child_days_prep "(ag3a_74_3) total number of hired child days spent on preparation and planting"
la var hired_women_days_weed "(ag3a_74_5) total number of hired women days spent on weeding"
la var hired_men_days_weed "(ag3a_74_6) total number of hired men days spent on weeding"
la var hired_child_days_weed "(ag3a_74_7) total number of hired child days spent on weeding"
la var hired_women_days_ridge "(ag3a_74_9) total number of hired women days spent on ridging and fertilizing"
la var hired_men_days_ridge "(ag3a_74_10) total number of hired men days spent on ridging and fertilizing"
la var hired_child_days_ridge "(ag3a_74_11) total number of hired child days spent on ridging and fertilizing"
la var hired_women_days_harv "(ag3a_74_13) total number of hired women days spent on harvesting"
la var hired_men_days_harv "(ag3a_74_14) total number of hired men days spent on harvesting"
la var hired_child_days_harv "(ag3a_74_15) total number of hired child days spent on harvesting"

//replace with zeros if they answered they didn't hire any labor on the plot 
local hiredvars hired_* 
foreach x of varlist `hiredvars' {
replace `x' = 0 if ag3a_73 == 2
} 


//Bysort by household so we can use a max collapse - use a loop. Note: using TOTAL instead of SUM because TOTAL allows the missing option
local laborvars hh_labor_days hh_prep_days hh_weed_days hh_ridge_days hh_harvest_days hired_* 

foreach x of varlist `laborvars' {
	egen tot_`x' = total(`x') if plot_tag==1, by(y3_hhid) missing
bysort y3_hhid: egen totplot=max(tot_`x') 
replace tot_`x'=totplot 
drop totplot 
	}

*************Creation of crop-level variables***************

////////////Now: can drop observations with no zaocode, because the area for other use has been summed and backfilled to all household observations and the following vars are only for cultivated plots
drop if zaocode ==. //882 deleted


******************AREA PLANTED (FR)*********************

*ag4a_01 "Was crop planted in entire area of plot?"
*ag4a_02 "Approx how much of the plot was planted with [crop]? 1/4, 1/2, 3/4"

*recode to get numeric values and make step variable for crops planted on less than 100% of the plot:
recode ag4a_02 (1=.25) (2=.5) (3=.75)
gen arpl_portion_ha= ag4a_02*plot_area
la var arpl_portion_ha "(ag4a_02 plot_area) portion of crop area planted in hectares (step variable to area_planted_ha)"

gen area_planted_ha = .
replace area_planted_ha = plot_area if ag4a_01==1
replace area_planted_ha = arpl_portion_ha if ag4a_01==2

*assert arpl_portion_ha==. if ag4a_01==1 // recheck assertion - means all obs either planted whole plot OR planted a portion
la var area_planted_ha "(ag4a_01-02 plot_area) annual crop area planted in hectares (gps if available, else FR)"


*************AREA HARVESTED********************
*ag4a_28 "What was the quantity harvested?(KGs)"
gen harv_quant_kg = .
replace harv_quant_kg = ag4a_28
replace harv_quant_kg =0 if ag4a_19==2 & ag4a_20==3
label var harv_quant_kg "(ag4a_28) Harvested Quantity(KGs), LRS_2012"

*ag4a_29 "What is the estimated value of the harvest crop? (TZ_Shillings)"
gen harv_value_tsh = .
replace harv_value_tsh = ag4a_29
label var harv_value_tsh "(ag4a_29) Value of Harvested Crop (Tz_Shillings), LRS_2012"

*ag4a_21 "What was the area harvested in the LRS 2012?"
*replace with zero if answered no to ag4a_19: "Did you harvest any [crop] on this plot in LRS 2012"
* AND ag4a_20 "Why didn't you harvest any [crop] on this plot" 1. not mine, 2. still in plot, 3. destruction, 4. other
* NOTE: We are only converting to zero if they didn't harvest due to DESTRUCTION (CODE=3)
gen area_harvested_ac = ag4a_21
replace area_harvested_ac =0 if ag4a_19==2 & ag4a_20==3
la var area_harvested_ac "(ag4a_19 ag4a_20 ag4a_21) area harvested in acres, farmer report, capped at plot_area"

*convert to hectares
gen area_harvested_ha = .
replace area_harvested_ha = area_harvested_ac* 0.404685642

*cap area harvested at plotsize if reported area harvested was over GPS plotsize
replace area_harvested_ha = plot_area if area_harvested_ha > plot_area & area_harvested_ha !=. //1737 changes
la var area_harvested_ha "(ag4a_19-21) area harvested in hectares LRS 2012, farmer report, capped at plot_area"


//fruits
gen grew_fruit = 0
replace grew_fruit = 1 if ag6a_02 !=. //if they had at least one fruit tree
la var grew_fruit "household grew any fruit crops in 2012 (ag6a_02)"

gen number_fruits = ag6a_02
la var number_fruits "number of plants/trees on the plot (ag6a_02)"

gen number_fruits_12months = ag6a_04
la var number_fruits_12months "number of trees/plants planted in last 12 months (ag6a_04)"

gen harvest_quant_fruit = ag6a_09
la var harvest_quant_fruit "total amount of fruit harvested (ag6a_09)"

//permanent crops
gen grew_perm = 0
replace grew_perm = 1 if ag6b_02 !=. //if they had at least one permanent crop plant
la var grew_perm "household grew any permanent crops in 2012 (ag6b_02)"

gen number_perm = ag6b_02
la var number_perm "number of plants/trees on the plot (ag6b_02)"

gen number_perm_12months = ag6b_04
la var number_perm_12months "number of trees/plants planted in last 12 months (ag6b_04)"

gen harvest_quant_perm = ag6b_09
la var harvest_quant_perm "total amount of permanent crop harvested (ag6b_09)"


********MAKE VARIABLES THAT SUM ALLOCATION BY CROP //This is unnecessary because now that coding errors have been corrected, the collapse IS working to sum up area (although rounding is slightly different).
//However, we have based all our analysis variables and descriptives on these variables, so it will be easier not to delete them. 
egen crop_allocation = sum(plot_area) if plot_area!=., by(y3_hhid zaocode) 
bysort y3_hhid zaocode: egen totplot=max(crop_allocation) 
replace crop_allocation=totplot 
drop totplot 

egen arpl_crop = sum(plot_area) if plot_area!=., by(y3_hhid zaocode) 
bysort y3_hhid zaocode: egen totplot=max(arpl_crop) 
replace arpl_crop =totplot 
drop totplot 

egen harv_quant_annual_crop = sum(harv_quant_kg) if harv_quant_kg!=., by(y3_hhid zaocode)
bysort y3_hhid zaocode: egen totplot=max(harv_quant_annual_crop) 
replace harv_quant_annual_crop =totplot 
drop totplot 

egen harv_quant_perm_crop = sum(harvest_quant_perm) if harvest_quant_perm!=., by(y3_hhid zaocode)
bysort y3_hhid zaocode: egen totplot=max(harv_quant_perm_crop) 
replace harv_quant_perm_crop =totplot 
drop totplot 

egen harv_quant_fruit_crop = sum(harvest_quant_fruit) if harvest_quant_fruit!=., by(y3_hhid zaocode)
bysort y3_hhid zaocode: egen totplot=max(harv_quant_fruit_crop) 
replace harv_quant_fruit_crop =totplot 
drop totplot 

egen arhv_crop = sum(area_harvested_ha) if area_harvested_ha!=., by(y3_hhid zaocode)
bysort y3_hhid zaocode: egen totplot=max(arhv_crop) 
replace arhv_crop =totplot 
drop totplot 

la var crop_allocation "sum of all plot area for crop, by household (arpl, gps if available, else FR)"
la var arpl_crop "sum of total area planted for annual crop, by household (gps if available, else FR)"
la var harv_quant_annual_crop "sum of harvest quantity for annual crop, by household"
la var harv_quant_perm_crop "sum of harvest quantity for permanent crop, by household"
la var harv_quant_fruit_crop "sum of harvest quantity for fruit crop, by household"
la var arhv_crop "sum of area harvested for annual crop, by household (farmer report capped at plotsize)"

count if crop_allocation > sum_plot_area & crop_allocation !=. //0
count if arpl_crop > sum_plot_area & arpl_crop !=. //0 

**if you want to preserve more variables, add them to these local lists
local countcollapse plot_cultivated
local maxcollapse grew_fruit grew_perm grew_annual crop_allocation sum_plot_area arpl_crop ///
harv_quant_annual_crop harv_quant_fruit_crop harv_quant_perm_crop arhv_crop ///
landuse_cultivated_ha tot* nmbr_plots ///
landuse_ic_ap soil_type soil_quality plot_irrigated org_fert inorg_fert pest_herb_usage

local sumcollapse plot_area area_planted_ha harv_quant_kg harv_value_tsh area_harvested_ha number_fruits number_fruits_12months /// 
harvest_quant_fruit number_perm number_perm_12months harvest_quant_perm fr_hh

collapse (count) `countcollapse' (max) `maxcollapse' (sum) `sumcollapse', by (y3_hhid zaocode) 

//label variables
la var sum_plot_area "sum of all HH plots in ha LRS 2012 - GPS-based if available, else farmer-report"
la var plot_area "plot area measure, ha - GPS-based if they have one, farmer-report if not"
la var area_planted_ha "(ag4a_01-02 plot_area) crop area planted in hectares (gps if available, else FR)"
la var harv_quant_kg "(ag4a_15) Harvested Quantity(KGs), LRS_2012"
la var harv_value_tsh "(ag4a_16) Value of Harvested Crop (Tz_Shillings), LRS_2012"
la var area_harvested_ha "(ag4a_06-08) area harvested in hectares, farmer report, capped at plot_area"
la var number_fruits "number of plants/trees on the plot (ag6a_02)"
la var number_fruits_12months "number of trees/plants planted in last 12 months (ag6a_04)"
la var harvest_quant_fruit "total amount of fruit harvested (ag6a_08)"
la var number_perm "number of plants/trees on the plot (ag6b_02)"
la var number_perm_12months "number of trees/plants planted in last 12 months (ag6b_04)"
la var harvest_quant_perm "total amount of permanent crop harvested (ag6b_08)"
la var grew_fruit "household grew any fruit crops in 2012 (ag6a_02)"
la var grew_perm "household grew any permanent crops in 2012 (ag6b_02)"
la var grew_annual "hh grew annual crops in 2012 (answered section 4)"
la var plot_cultivated "number of plots of this crop cultivated by household during LRS 2012 (ag3a_38)"
la var crop_allocation "sum of all plot area for crop, by household"
la var arpl_crop "sum of total area planted for this crop, by household"
la var harv_quant_annual_crop "sum of harvest quantity for annual crop, by household"
la var harvest_quant_perm "sum of harvest quantity for permanent crop, by household"
la var harvest_quant_fruit "sum of harvest quantity for fruit crop, by household"
la var arhv_crop "sum of area harvested for annual crop, by household"
la var fr_hh "number of plots without a GPS measure (farmer-reported area used)"
la var landuse_cultivated_ha "Total area cultivated, ha" 
la var nmbr_plots "(plotnum) count of plots by household"
la var tot_hh_labor_days "(rowtotal ag3a_72) total number of HH labor days on plot - all crops"
la var tot_hh_prep_days "(rowtotal ag3a_72_1-_6) total number of HH labor days spent on prep and planting"
la var tot_hh_weed_days "(rowtotal ag3a_72_7-_12) total number of HH labor days spent on weeding"
la var tot_hh_ridge_days "(rowtotal ag3a_72_13-_18) total number of HH labor days spent on ridging and fertilizing"
la var tot_hh_harvest_days "(rowtotal ag3a_72_19-_24) total number of HH labor days spent on harvesting"
la var tot_hired_labor_days "(ag3a_74) total number of hired labor days"
la var tot_hired_prep_days "(rowtotal ag3a_74_1-_3) total number of hired labor days spent on prep and planting"
la var tot_hired_weed_days "(rowtotal ag3a_74_5-_7) total number of hired labor days spent on weeding"
la var tot_hired_ridge_days "(rowtotal ag3a_74_9-_11) total number of hired labor days spent on ridging and fertilizing"
la var tot_hired_harvest_days "(rowtotal ag3a_74_13-_15) total number of hired labor days spent on harvesting"
la var tot_hired_women_days_prep "(ag3a_74_1) total number of hired women days spent on prep and planting"
la var tot_hired_men_days_prep "(ag3a_74_2) total number of hired men days spent on prep and planting"
la var tot_hired_child_days_prep "(ag3a_74_3) total number of hired child days spent on prep and planting"
la var tot_hired_women_days_weed "(ag3a_74_5) total number of hired women days spent on weeding"
la var tot_hired_men_days_weed "(ag3a_74_6) total number of hired men days spent on weeding"
la var tot_hired_child_days_weed "(ag3a_74_7) total number of hired child days spent on weeding"
la var tot_hired_women_days_ridge "(ag3a_74_9) total number of hired women days spent on ridging and fertilizing"
la var tot_hired_men_days_ridge "(ag3a_74_10) total number of hired men days spent on ridging and fertilizing"
la var tot_hired_child_days_ridge "(ag3a_74_11) total number of hired child days spent on ridging and fertilizing"
la var tot_hired_women_days_harv "(ag3a_74_13) total number of hired women days spent on harvesting"
la var tot_hired_men_days_harv "(ag3a_74_14) total number of hired men days spent on harvesting"
la var tot_hired_child_days_harv "(ag3a_74_15) total number of hired child days spent on harvesting"
label var landuse_ic_ap "Dummy if plot cultivated is intercropped, all crops"
label var soil_type "(ag3a_10) Type of soil on the plot, 1=sandy, 2=loam, 3=clay, 4=other"
label var soil_quality "(ag3a_11) Soil quality on the plot, 1=good, 2=average, 3=bad"
label var plot_irrigated "(ag3a_18) Dummy if plot was irrigated"
label var org_fert "(ag3a_41) Dummy if used organic fertilizer"
label var inorg_fert "(ag3a_47) Dummy if used inorganic fertilizer"
label var pest_herb_usage "(ag3a_60) Dummy if used pesticides or herbicides"


count if crop_allocation > sum_plot_area & crop_allocation !=. //0
count if arpl_crop > sum_plot_area & arpl_crop !=. //0 
 
save "$collapse/plot_to_crop_hh.dta", replace

************************MERGE EVERYTHING TOGETHER*******************************
//now we will put together the collapsed data with the raw and cleaned data at the hh and hh-crop level
clear
use "$input\Agriculture\AG_SEC_A.dta" 


**add in collapsed plot level
merge 1:m y3_hhid using "$collapse/plot_to_crop_hh.dta", gen (_plot_collapse)
**14717 matched, 1828 not matched from master

//DATASET IS NOW AT HH-CROP LEVEL

**add in 7A: Fruit crops total
merge 1:1 y3_hhid zaocode using "$collapse\AG_SEC_7A_prepped.dta", gen (_fruit_total) //note these will not match to the obs with changed zaocodes
**4881 matched, 11664 not matched from master, 5 not matched from using

**add in 7B: Permanent crops total
merge 1:1 y3_hhid zaocode using "$collapse\AG_SEC_7B_prepped.dta", gen (_perm_total)
**3512 matched, 13,038 not matched from master, 12 not matched from using (mostly renamed)

**add in 5A
merge m:1 y3_hhid zaocode using "$collapse\AG_SEC_5A_prepped.dta", gen (_crop_hhtotal)
**6153 matched, 10,409 not matched from master, 3 not matched from using

**drop non-cultivating hh - only using ag hh in this analysis
drop if zaocode==. //1828 obs deleted
//n=14,737

isid y3_hhid zaocode, missok

**Now redefining the labels for zaocode to reflect old zaocodes and zaocodes created to eliminate duplicates - doing this just once to fix duplicates labels from all sections
label define zaocodel 11 "Maize" 12 "Paddy" 13 "Sorghum" 14 "Bulrush Millet" 15 "Finger Millet" 16 "Wheat" 17 "Barley" 18 "Black pepper" /*
*/21 "Cassava" 22 "Sweet Potatoes" 23 "Irish Potatoes" 24 "Yams" 25 "Cocoyams" 26 "Onions" 27 "Ginger" 31 "Beans" 32 "Cowpeas" 33 "Green gram" /*
*/34 "Pigeon pea" 35 "Chick peas" 36 "Bambara nuts" 37 "Field Peas" 41 "Sunflower" 42 "Sesame" 43 "Groundnut" 47 "Soyabeans" 48 "Caster seed" /*
*/70 "Passion Fruit" 71 "Banana" 72 "Avocado" 73 "Mango" 74 "Papaw" 76 "Orange" 77 "Grapefruit" 78 "Grapes" 79 "Mandarin" 80 "Guava" 81 "Plums (see also 203)" /*
*/82 "Apples" 83 "Pears" 84 "Peaches (see also 204)" 851 "Lime" 852 "Lemon" 68 "Pomelo" 69 "Jack fruit" 97 "Durian" 98 "Bilimbi" 99 "Rambutan" 67 "Bread fruit" /*
*/38 "Malay apple" 39 "Star fruit" 200 "Custard apple" 201 "God fruit" 202 "Mitobo" 203 "Plum (see also 81)" 204 "Peaches (see also 84)" /*
*/205 "Pomegranate" 210 "Date" 211 "Tungamaa" 212 "Vanilla" 86 "Cabbage" 87 "Tomatoes" 88 "Spinach" 89 "Carrot" 90 "Chilies" 91 "Amaranths" /*
*/92 "Pumpkins" 93 "Cucumber" 94 "Egg Plant" 95 "Water Melon" 96 "Cauliflower" 100 "Okra" 101 "Fiwi" 50 "Cotton" 51 "Tobacco" 52 "Pyrethrum" /*
*/62 "Jute" 19 "Seaweed" 53 "Sisal" 54 "Coffee" 55 "Tea" 56 "Cocoa" 57 "Rubber" 58 "Wattle" 59 "Kapok" 60 "Sugar cane" 61 "Cardamom" 63 "Tamarind" /*
*/ 64 "Cinammon" 65 "Nutmeg" 66 "Clove" 75 "Pineapple" 44 "Palm oil" 45 "Coconut" 46 "Cashew nut" 300 "Green Tomato" /*
*/301 "Monkeybread" 302 "Bamboo" 303 "Firewood/fodder" 304 "Timber" 305 "Medicinal plant" 306 "Fence tree" 401 "Other Timber1" /*
*/402 "Other Timber2" 403 "Other Timber3" 404 "Other Timber4" 405 "Other Timber5" 406 "Other Timber6" 501 "Other firewood/fodder1" /*
*/502 "Other firewood/fodder2" 601 "Other Cassava1" 602 "Other Cassava2" 701 "Other Coconut1" 801 "Other Cashew1" 901 "Other" 902 "Other" /*
*/998 "Other" 999 "Other" 1001 "Other Coffee" 1101 "Other banana1" 1102 "Other banana2" 1201 "Other Mango" 1301 "Other Beans" 1801 "Other medicinal plant"
label val zaocode zaocodel

///////////////////////SKIPPING SHORT RAINY SEASON FOR THIS ANALYSIS


****************MERGE AG COLLAPSES*****************************************
//household section J1 - maize consumption
merge m:1 y3_hhid using "$collapse/HH_SEC_J1_maize_consumption.dta", keep (1 3) gen (_hh_maizecons)


/////////////////////MERGE OTHER SECTIONS

/////////////////merge in hh and plot level geovariables 
codebook y3_hhid //3186 HH
isid y3_hhid zaocode, missok
//n=14737 

merge m:1 y3_hhid using "$input\Household\HouseholdGeovars_y3.dta", keep(1 3) gen(_hh_geovars)
//14727 matched, 10 not matched from master, not keeping unmatched vars from using
// 10 hh don't have hh-level geovars 

*egen y3_hhid_plot = concat(y3_hhid plotnum) // creating this var to check number of unique plots 
*codebook y3_hhid_plot // 7464 unique plots no missings


***MERGE in consumption dta
merge m:1 y3_hhid using "$input/ConsumptionNPS3.dta", keep (1 3) gen(_hh_consumption)
//14,452 matched, 285 not matched from master. The consumption data only includes 4883 HH. 

*merge in y3_hhid y2_hhid indidy3 hh_b01 hh_b02 hh_b04 hh_b05 hh_c0* from HH_SEC_B
merge m:1 y3_hhid using "$collapse\HH_merge.dta", keep (1 3) gen (_household_B)
//14,737 matched

//n=14,737
codebook y3_hhid //3186 ag hh in analysis.

 
//add _2012 to the end with a loop
foreach x of varlist *{
rename `x' `x'_2012
}

//name these back as we need to merge on them
rename y2_hhid_2012 y2_hhid
rename zaocode_2012 zaocode
rename y3_hhid_2012 y3_hhid

gen hhid_p = y3_hhid
replace hhid_p = y2_hhid if hh_a13_2012==1 & y2_hhid != ""
//now hhid_p is equal to y2_hhid for original hh in both panels, and it is equal to a different # (y3_hhid) for all others, these will be not matched from using when we merge

isid y3_hhid zaocode
isid hhid_p zaocode

gen wave3 =1
la var wave3 "observation existed in wave 3"


**Now we will create an identifier for whether a household experienced a split-off between 2010 and 2012. 
*br y3_hhid y2_hhid hh_a06_2012 hh_a13_2012 hh_a09_2012 hh_a10_2012 hh_a11_2012

//make a dummy var equal to 1 if hh was a "child" splitoff (split off to a new location)
gen splitoff_child_2012 =.
replace splitoff_child_2012 =1 if hh_a10_2012 ==2
replace splitoff_child_2012 =0 if hh_a10_2012 ==1
la var splitoff_child_2012 "hh is a 'child' splitoff (hh_a10)"

//make a dummy var equal to 1 if hh experienced a split since 2010 (is either "parent" or "child" hh), equal to 0 ONLY if it did not split
*hh_a09 has 2010 HHIDs for ALL households, not just original households - we will sort by that
egen experienced_splitoff_2012 = max(splitoff_child_2012), by(hh_a09_2012)
la var experienced_splitoff_2012 "hh experienced splitoff between 2010 and 2012 - original OR child (hh_a09 hh_a10)"

//make a dummy that identifies the "parent" hh that experienced a split only
gen splitoff_parent_2012 =.
replace splitoff_parent_2012 =1 if experienced_splitoff_2012 ==1 & splitoff_child_2012 ==0 
replace splitoff_parent_2012 =0 if experienced_splitoff_2012 ==0 
replace splitoff_parent_2012 =0 if splitoff_child_2012 ==1
la var splitoff_parent_2012 "hh is a 'parent' that experienced a split (hh_a09 hh_a10)"

codebook y3_hhid if splitoff_child_2012 ==1 //674
codebook y3_hhid if splitoff_parent_2012 ==1 //426
codebook y3_hhid if experienced_splitoff_2012 ==0 //2086
display 2086+426+674 //3186, same as: 
codebook y3_hhid

//make a dummy for hh that moved location from 2008-2010
gen hh_moved_2012 = .
replace hh_moved_2012 =0 if hh_a11_2012 ==1
replace hh_moved_2012 =1 if hh_a11_2012 >1
la var hh_moved_2012 "household moved between 2010 and 2012 (hh_a11)"

//if we want to merge "child" households to their 2010 "parent", will need to rename hh_a09 to y2_hhid

//SAVE for panel merge
save "$merge\w3_panel_merge", replace

