***************************************************************************************************************
*Title/Purpose of Do File: Tanzania LSMS-ISA (2008, 2010, 2012) - Ag survey - PANEL MERGE AND VARIABLE CREATION (Shiny agricultural productivity app)
*Unique identifiers (level): y3_hhid zaocode
*Author(s): Katie Panhorst Harris/Maggie Beetstra
*Date started: 12/10/15
*Date completed: 1/9/17

*CHECKED BY: David Coomes
*DATE: 1/9/17
***************************************************************************************************************

*This file to be run last

//SET DIRECTORIES - make sure to reset these
clear
global input "FILEPATH\Merged Data Shiny" //Reset to where you have been saving output data
global merge "FILEPATH\Merged Data Shiny" //set up an output folder to save .dtas to use in the panel merge

//Panel merge: begin with W1 and merge in W2 
use "$input\2008 data\Merged Data Shiny\wave1_merged_shiny" //generated in Wave 1 Merge do file 
merge 1:1 hhid_p zaocode using "$input\2010 data\Merged Data Shiny\W2_merged_shiny", gen (_W2) //generated in Wave 2 Merge do file
**matched 5663, 3,674 not matched from master, 6,352 not matched from using
**each observation represents one crop of one household

//add W3
merge 1:1 hhid_p zaocode using "$input\2012-13 data\Merged Data Shiny\w3_panel_merge", gen (_W3) //generated in Wave 3 Merge do file
**matched 8017, 7672 not matched from master, 6720 not matched from using
*Note that any variable with _x_ in the name was renamed to allow data reshaping, but not otherwise altered.

//add clustered median prices for all three waves, generated in Shadow Prices do file
merge 1:1 hhid_p zaocode using "$input\2008 data\Merged Data Shiny\W1_shadowprice.dta", gen(_price_W1)
**1394 matched, 21015 not matched from master (non-maize or not in W1)
merge 1:1 hhid_p zaocode using "$input\2010 data\Merged Data Shiny\W2_shadowprice.dta", gen(_price_W2)
**1570 matched, 20839 not matched from master (non-maize or not in W2)
merge 1:1 hhid_p zaocode using "$input\2012-13 data\Merged Data Shiny\W3_shadowprice.dta", gen(_price_W3)
**2067 matched, 20342 not matched from master (non-maize or not in W3)


isid hhid_p zaocode
codebook hhid_p //3653 total households

//now we need to backfill hhid_2008, y2_hhid, and y3_hhid for all observations within a given hhid_p - these may be empty if they didn't grow the same crop each year.
bysort hhid_p: egen allplots=mode(hhid_2008) //mode will work with a string - if it is all missings, it will stay missing.
replace hhid_2008=allplots
drop allplots //this was just a step variable

bysort hhid_p: egen allplots=mode(y2_hhid) //mode will work with a string - if it is all missings, it will stay missing.
replace y2_hhid=allplots
drop allplots //this was just a step variable

bysort hhid_p: egen allplots=mode(y3_hhid) //mode will work with a string - if it is all missings, it will stay missing.
replace y3_hhid=allplots
drop allplots //this was just a step variable

//Set survey weights
*(right now, if a certain crop wasn't grown in a given year, that observation has no weights for the other years even if the hh existed)
*Apply 2008 survey weights, clusters, and strata to 2010 and 2012 observations since we can't have three sets of survey weights (hh_weight_2008 = weights for 2008)
egen panelweight = max(hh_weight_2008), by (hhid_p) 
egen panelcluster = max(clusterid_2008), by (hhid_p)
egen panelstrata = max(strataid_2008), by (hhid_p)

la var panelweight "2008 weights filled into all HH observations for panel analysis"
la var panelcluster "2008 clusters filled into all HH observations for panel analysis"
la var panelstrata "2008 strata filled into all HH observations for panel analysis"

svyset panelcluster [pweight= panelweight], strata(panelstrata) singleunit(centered)



//////////////////////////////////////
**		Make Crop Categories		**
//////////////////////////////////////

//Clean permanent crops// 
* Transfer annual crop values from permanent variables into  LRS variables
* Cassava, cashew nut, pigeonpea have overlapping data for LRS and PERM
* Values reported for both LRS and PERM are largely the same and the LRS reports slightly more values. Therefore the code replaces the perm value with the lrs value.

//Run from here through the end of the loop all together
* local list of permanent zaocode numbers
local annualcrops "11 12 13  14  15 16 17 18 21 22 23 24 25 26 27 31 32 33 34 35 36 37 41 42 43 47 48 1301"

* local lists of the transferable variables between section 4 and 6 -- the only equivalent we have right now in the variables we preserved through the collapse is harvest quant
local permvars harv_quant_perm_crop_2008 harv_quant_perm_crop_2010 harv_quant_perm_crop_2012
local lrsvars harv_quant_annual_crop_2008 harv_quant_annual_crop_2010 harv_quant_annual_crop_2012

* create locals to tell stata which number in the previous locals to look at
* local for number of zaocodes
local n : word count `annualcrops'
* local for number of variables
local m : word count `permvars'

* tell stata to loop through each zaocode #
forvalues i=1/`n'{
	* tell stata to loop through each variable
	forvalues j=1/`m'{
* tell stata to loop through each zaocode
local x : word `i' of `annualcrops'
* tell stata to loop through each variable
local y : word `j' of `permvars'
local z : word `j' of `lrsvars'

* replace the LRS variables value with the perm variable value if the zaocode is a permanent zaocode and the lrs variable value is not missing
replace `z'=`y' if zaocode==`x' & `y'!=.
}
}
//now these numbers are in both places, in the annual crops AND permanent crops section.

**Make three categories of crop: Maize, other annual, and permanent. We will use this to see what maize farmers shift into and out of.
//give a different value (994, because that one's not taken yet) to "other" ANNUAL crops, exisiting other codes will be for "other" PERMANENT
replace zaocode = 994 if zaocode ==998 & (harv_quant_annual_crop_2008 !=. | harv_quant_annual_crop_2010 !=. | harv_quant_annual_crop_2012 !=.) //if it has at least one annual crop harvest quant value - this may miss some obs, but it will catch all the ones we can use (because we need harv quant to get yield)

gen cropcat =.
replace cropcat =1 if zaocode ==11 //maize
replace cropcat =2 if (zaocode >11 & zaocode < 18) |  (zaocode > 18 & zaocode <38) | (zaocode >40 & zaocode <44) | (zaocode >46 & zaocode <53) | zaocode ==62  | zaocode ==1301 | zaocode ==601 | zaocode ==602 | zaocode ==994 //annual including annual cash, see list below 
replace cropcat =3 if zaocode ==38 | zaocode ==39 | (zaocode >43 & zaocode < 47) | (zaocode >52 & zaocode < 62) | (zaocode >62 & zaocode < 601) | (zaocode >602 & zaocode !=1301 & zaocode !=994)  //permanent and fruit, see lists below
la var cropcat "crop category: 1= maize, 2=other annual, 3=perm/fruit"
label define cropcat1 1 "maize" 2 "other annual" 3 "permanent/fruit" 
label val cropcat cropcat1

//LISTS FOR REFERENCE (FROM BACK PAGE OF AG QUESTIONNAIRE)
/* Annual crops: 12 "Paddy" 13 "Sorghum" 14 "Bulrush Millet" 15 "Finger Millet" 16 "Wheat" 17 "Barley" 18 "Black pepper" 
21 "Cassava" 22 "Sweet Potatoes" 23 "Irish Potatoes" 24 "Yams" 25 "Cocoyams" 26 "Onions" 27 "Ginger" 31 "Beans" 32 "Cowpeas" 33 "Green gram" 
34 "Pigeon pea" 35 "Chick peas" 36 "Bambara nuts" 37 "Field Peas" 41 "Sunflower" 42 "Sesame" 43 "Groundnut" 47 "Soyabeans" 48 "Caster seed" 1301 "Other Beans"
*Annual Cash Crops: 50 "Cotton" 51 "Tobacco" 52 "Pyrethrum" 62 "Jute" 19 "Seaweed" 601 "Other Cassava1" 602 "Other Cassava2"

Fruits: 70 "Passion Fruit" 71 "Banana" 72 "Avocado" 73 "Mango" 74 "Papaw" 76 "Orange" 77 "Grapefruit" 78 "Grapes" 79 "Mandarin" 80 "Guava" 81 "Plums (see also 203)" 
82 "Apples" 83 "Pears" 84 "Peaches (see also 204)" 851 "Lime" 852 "Lemon" 68 "Pomelo" 69 "Jack fruit" 97 "Durian" 98 "Bilimbi" 99 "Rambutan" 67 "Bread fruit" 
38 "Malay apple" 39 "Star fruit" 200 "Custard apple" 201 "God fruit" 202 "Mitobo" 203 "Plum (see also 81)" 204 "Peaches (see also 84)" 
205 "Pomegranate" 210 "Date" 211 "Tungamaa" 212 "Vanilla" 1101 "Other banana1" 1102 "Other banana2" 1201 "Other Mango" 

* Vegetables: 86 "Cabbage" 87 "Tomatoes" 88 "Spinach" 89 "Carrot" 90 "Chilies" 91 "Amaranths" 92 "Pumpkins" 93 "Cucumber" 94 "Egg Plant" 95 "Water Melon" 96 "Cauliflower" 100 "Okra" 101 "Fiwi" 

* Permanent Cash Crops: 53 "Sisal" 54 "Coffee" 55 "Tea" 56 "Cocoa" 57 "Rubber" 58 "Wattle" 59 "Kapok" 60 "Sugar cane" 61 "Cardamom" 63 "Tamarind" /*
*/ 64 "Cinammon" 65 "Nutmeg" 66 "Clove" 75 "Pineapple" 44 "Palm oil" 45 "Coconut" 46 "Cashew nut" 300 "Green Tomato" /*
*/301 "Monkeybread" 302 "Bamboo" 303 "Firewood/fodder" 304 "Timber" 305 "Medicinal plant" 306 "Fence tree" 401 "Other Timber1" /*
*/402 "Other Timber2" 403 "Other Timber3" 404 "Other Timber4" 405 "Other Timber5" 406 "Other Timber6" 501 "Other firewood/fodder1" /*
*/502 "Other firewood/fodder2"  701 "Other Coconut1" 801 "Other Cashew1" 901 "Other" 902 "Other" /*
*/998 "Other" 1001 "Other Coffee"   1801 "Other medicinal plant"
*/ 

**Now redefining the labels for zaocode again to make sure they are all correct - especially the new ones
label define zaocode2 11 "Maize" 12 "Paddy" 13 "Sorghum" 14 "Bulrush Millet" 15 "Finger Millet" 16 "Wheat" 17 "Barley" 18 "Black pepper" /*
*/21 "Cassava" 22 "Sweet Potatoes" 23 "Irish Potatoes" 24 "Yams" 25 "Cocoyams" 26 "Onions" 27 "Ginger" 31 "Beans" 32 "Cowpeas" 33 "Green gram" /*
*/34 "Pigeon pea" 35 "Chick peas" 36 "Bambara nuts" 37 "Field Peas" 41 "Sunflower" 42 "Sesame" 43 "Groundnut" 47 "Soyabeans" 48 "Caster seed" /*
*/70 "Passion Fruit" 71 "Banana" 72 "Avocado" 73 "Mango" 74 "Papaw" 76 "Orange" 77 "Grapefruit" 78 "Grapes" 79 "Mandarin" 80 "Guava" 81 "Plums (see also 203)" /*
*/82 "Apples" 83 "Pears" 84 "Peaches (see also 204)" 851 "Lime" 852 "Lemon" 68 "Pomelo" 69 "Jack fruit" 97 "Durian" 98 "Bilimbi" 99 "Rambutan" 67 "Bread fruit" /*
*/38 "Malay apple" 39 "Star fruit" 200 "Custard apple" 201 "God fruit" 202 "Mitobo" 203 "Plum (see also 81)" 204 "Peaches (see also 84)" /*
*/205 "Pomegranate" 210 "Date" 211 "Tungamaa" 212 "Vanilla" 86 "Cabbage" 87 "Tomatoes" 88 "Spinach" 89 "Carrot" 90 "Chilies" 91 "Amaranths" /*
*/92 "Pumpkins" 93 "Cucumber" 94 "Egg Plant" 95 "Water Melon" 96 "Cauliflower" 100 "Okra" 101 "Fiwi" 50 "Cotton" 51 "Tobacco" 52 "Pyrethrum" /*
*/62 "Jute" 19 "Seaweed" 53 "Sisal" 54 "Coffee" 55 "Tea" 56 "Cocoa" 57 "Rubber" 58 "Wattle" 59 "Kapok" 60 "Sugar cane" 61 "Cardamom" 63 "Tamarind" /*
*/ 64 "Cinnamon" 65 "Nutmeg" 66 "Clove" 75 "Pineapple" 44 "Palm oil" 45 "Coconut" 46 "Cashew nut" 300 "Green Tomato" /*
*/301 "Monkeybread" 302 "Bamboo" 303 "Firewood/fodder" 304 "Timber" 305 "Medicinal plant" 306 "Fence tree" 401 "Other Timber1" /*
*/402 "Other Timber2" 403 "Other Timber3" 404 "Other Timber4" 405 "Other Timber5" 406 "Other Timber6" 501 "Other firewood/fodder1" /*
*/502 "Other firewood/fodder2" 601 "Other Cassava1" 602 "Other Cassava2" 701 "Other Coconut1" 801 "Other Cashew1" 901 "Other permanent/fruit" 902 "Other permanent/fruit" /*
*/903 "Other permanent/fruit" 904 "Other permanent/fruit" 991 "Other permanent/fruit" 994 "Other ANNUAL" 995 "Other permanent/fruit" 996 "Other permanent/fruit" 997 /*
*/"Other permanent/fruit" 998 "Other permanent/fruit" 999 "Other permanent/fruit" 1001 "Other Coffee" 1101 "Other banana1" 1102 "Other banana2" 1201 "Other Mango" 1301 "Other Beans" 1801 "Other medicinal plant"
label val zaocode zaocode2

//////////////////////////////////////
**			Create Variables 		**
//////////////////////////////////////

//generate var for hh in all 3 panels
gen three_panel =0
replace three_panel=1 if y3_hhid != "" & y2_hhid !="" & hhid_2008 !=""
la var three_panel "HH present in all three panels of data (hhid_2008 y2_hhid y3_hhid)"
codebook hhid_p if three_panel ==1 //1811 panel HH in analysis 
codebook hhid_p //3653 total hh in analysis

************** 	YIELD	*********************************
**First, make the yield variables for each wave. Will do separately for annual and permanent because permanent does not have an AREA planted/harvested measure, only plotsize.
**Note we have collapsed to the crop-hh level, so "plotsize" is the sum of all area under that crop cultivated by the HH
**We use farmer-reported measures throughout this section.

*******TRIMMING OUTLIERS
**Trim underlying yield vars here at 99% 
*local list of variables to trim at 1% level
local trimming harv_quant_annual* arpl_crop*
* local list of permanent zaocode numbers
local annualcrops "11 12 13  14  15 16 17 18 21 22 23 24 25 26 27 31 32 33 34 35 36 37 41 42 43 47 48 1301"
* local for number of zaocodes
local n : word count `annualcrops'

* tell stata to loop through each variable
	foreach y of varlist `trimming'{
* tell stata to loop through each zaocode #
forvalues i=1/`n'{
	local x : word `i' of `annualcrops'
		_pctile `y' [aweight = panelweight] if zaocode==`x', nq(100)
		replace `y' = . if `y'>r(r99) & zaocode==`x'
}
}


**Manually changing the yield for hhid_p 1002011311001901 to missing because they report a 593052.9 kg/ha yield on 0.0020234 ha of land in 2008 and 1038.42 kg/ha yield on 1.42854 ha of land in 2010
replace harv_quant_annual_crop_2008 = . if hhid_p == "1002011311001901" & zaocode ==11 //changing the harvest quantity for maize observations, this means neither yield measure can be calculated for this hh.

*yield by area harvested, annual crops. All observations without area harvested (includes all cassava obs that were permanent) will have a missing value.
gen yield_arhv_ha_2008 = .
replace yield_arhv_ha_2008 = harv_quant_annual_crop_2008/arhv_crop_2008 if wave1==1
la var yield_arhv_ha_2008 "(harv_quant/area_harvested_ha) 2008 annual crop yield by area harvested kg/ha"

gen yield_arhv_ha_2010 = .
replace yield_arhv_ha_2010 = harv_quant_annual_crop_2010/arhv_crop_2010 if wave2==1
la var yield_arhv_ha_2010 "(harv_quant/area_harvested_ha) 2010 annual crop yield by area harvested kg/ha"

gen yield_arhv_ha_2012 = .
replace yield_arhv_ha_2012 = harv_quant_annual_crop_2012/arhv_crop_2012 if wave3==1
la var yield_arhv_ha_2012 "(harv_quant/area_harvested_ha) 2012 annual crop yield by area harvested kg/ha"

*yield by area planted, annual crops
gen yield_arpl_ha_2008 = .
replace yield_arpl_ha_2008 = harv_quant_annual_crop_2008/arpl_crop_2008 if wave1==1
la var yield_arpl_ha_2008 "(harv_quant/area_planted_ha) 2008 annual crop yield by area planted kg/ha"

gen yield_arpl_ha_2010 = .
replace yield_arpl_ha_2010 = harv_quant_annual_crop_2010/arpl_crop_2010 if wave2==1
la var yield_arpl_ha_2010 "(harv_quant/area_planted_ha) 2010 annual crop yield by area planted kg/ha"

gen yield_arpl_ha_2012 = .
replace yield_arpl_ha_2012 = harv_quant_annual_crop_2012/arpl_crop_2012 if wave3==1
la var yield_arpl_ha_2012 "(harv_quant/area_planted_ha) 2012 annual crop yield by area planted kg/ha"

*change in yield by area harvested, annual crops
gen yield_change_arhv_2008_2010 = yield_arhv_ha_2010-yield_arhv_ha_2008 
la var yield_change_arhv_2008_2010 "change in yield by area harvested from 2008-2010, annual crops"

gen yield_change_arhv_2010_2012 = yield_arhv_ha_2012-yield_arhv_ha_2010 
la var yield_change_arhv_2010_2012 "change in yield by area harvested from 2010-2012, annual crops"

*change in yield by area planted, annual crops
gen yield_change_arpl_2008_2010 = yield_arpl_ha_2010-yield_arpl_ha_2008 
la var yield_change_arpl_2008_2010 "change in yield by area planted from 2008-2010, annual crops"

**Manually changing the yield for hhid_p 1002011311001901 to missing because they report a 593052.9 kg/ha yield on 0.0020234 ha of land in 2008 and 1038.42 kg/ha yield on 1.42854 ha of land in 2010
replace yield_change_arpl_2008_2010 = . if hhid_p == "1002011311001901"

gen yield_change_arpl_2010_2012 = yield_arpl_ha_2012-yield_arpl_ha_2010
la var yield_change_arpl_2010_2012 "change in yield by area planted from 2010-2012, annual crops"

*change in farm size 
*Some of these are not plugged in for every value of the HH, so we can't use a HH tag to take means yet - need to bysort
egen farmsize_ha_2008 = max(sum_plot_area_2008), by(hhid_p) 
bysort hhid_p: egen allplots=max(farmsize_ha_2008)
replace farmsize_ha_2008=allplots
drop allplots
la var farmsize_ha_2008 "Total farm size, ha, 2008 (sum of all plots owned/cultivated by HH)"

egen farmsize_ha_2010 = max(sum_plot_area_2010), by(hhid_p)
bysort hhid_p: egen allplots=max(farmsize_ha_2010)
replace farmsize_ha_2010=allplots
drop allplots
la var farmsize_ha_2010 "Total farm size, ha, 2010 (sum of all plots owned/cultivated by HH)"

egen farmsize_ha_2012 = max(sum_plot_area_2012), by(hhid_p)
bysort hhid_p: egen allplots=max(farmsize_ha_2012)
replace farmsize_ha_2012=allplots
drop allplots
la var farmsize_ha_2012 "Total farm size, ha, 2012 (sum of all plots owned/cultivated by HH)"

//tag one observation per hh to run household level descriptives 
egen hh_tag = tag(hhid_p) 
la var hh_tag "household level tag"

egen hh_cat_tag = tag (hhid_p cropcat)
la var hh_cat_tag "household-crop category tag (maize/other annual/perm)"


**Then, make area under each crop category
gen allocation_2008 =.
replace allocation_2008 = crop_allocation_2008 if wave1==1 
replace allocation_2008 = arpl_crop_2008 if wave1==1 & arpl_crop_2008 !=.
la var allocation_2008 "area allocated to crop, ha, 2008"

gen allocation_2010 =.
replace allocation_2010 = crop_allocation_2010 if wave2==1
replace allocation_2010 = arpl_crop_2010 if wave2==1 & arpl_crop_2010 !=.
la var allocation_2010 "area allocated to crop, ha, 2010"

gen allocation_2012 =.
replace allocation_2012 = crop_allocation_2012 if wave3==1
replace allocation_2012 = arpl_crop_2012 if wave3==1 & arpl_crop_2012 !=.
la var allocation_2012 "area allocated to crop, ha, 2012" 

count if allocation_2008 ==. & wave1 ==1 //19
count if allocation_2010 ==. & wave2 ==1 //0
count if allocation_2012 ==. & wave3 ==1 //20

************* Need these variables that indicate which hh cultivated when in order to finish the allocation by category
//Variables for growing maize/cultivating by wave: different suffixes here so these will come through as variables after the reshape (for Shiny app)
gen grew_any_W1 = 0
replace grew_any_W1 = 1 if plot_cultivated_2008 !=. //if they cultivated any number of plots in 2008. This is the same as "wave1" except that one is not bysorted, and this one will be.

gen grew_any_W2 = 0
replace grew_any_W2 = 1 if plot_cultivated_2010 !=.

gen grew_any_W3 = 0
replace grew_any_W3 = 1 if plot_cultivated_2012 !=.

gen grew_maize_W1 = 0
replace grew_maize_W1 = 1 if zaocode ==11 & plot_cultivated_2008 !=.
replace grew_maize_W1 = . if wave1 !=1 //if the observation did not exist in W1

gen grew_maize_W2 = 0
replace grew_maize_W2 = 1 if zaocode ==11 & plot_cultivated_2010 !=.
replace grew_maize_W2 = . if wave2 !=1 //if the observation did not exist in W2

gen grew_maize_W3 = 0
replace grew_maize_W3 = 1 if zaocode ==11 & plot_cultivated_2012 !=.
replace grew_maize_W3 = . if wave3 !=1 //if the observation did not exist in W3

gen grew_maize_allwaves = 0
replace grew_maize_allwaves = 1 if grew_maize_W1 ==1 & grew_maize_W2 ==1 & grew_maize_W3 ==1

//bysort now, so that grew_any_allwaves will catch if they cultivated at all in all 3 waves, rather than if they cultivated any single crop in all 3 waves
local growing grew_maize* grew_any* 

foreach x of varlist `growing' {
	quietly bys hhid_p: egen b`x' = max(`x')
	quietly replace `x' = b`x'
	drop b`x'
	}
	
gen grew_any_allwaves = 0
replace grew_any_allwaves = 1 if grew_any_W1 ==1 & grew_any_W2 ==1 & grew_any_W3 ==1

gen grew_maize_1and2only = 0
replace grew_maize_1and2only = 1 if grew_maize_W1 ==1 & grew_maize_W2 ==1 & grew_maize_W3 ==0 

gen grew_maize_2and3only = 0
replace grew_maize_2and3only = 1 if grew_maize_W2 ==1 & grew_maize_W3 ==1 & grew_maize_W1 ==0 

gen grew_maize_1only = 0
replace grew_maize_1only = 1 if grew_maize_W1 ==1 & grew_maize_W2 ==0 & grew_maize_W3 ==0 

gen left_farming_W2 =0
replace left_farming_W2 =1 if grew_maize_W1 ==1 & grew_maize_W2 ==0 & grew_any_W3 ==0

gen left_farming_W3 =0
replace left_farming_W3 =1 if grew_maize_W1 ==1 & grew_maize_W2 ==1 & grew_any_W3 ==0

local left grew_maize* left_*

foreach x of varlist `left' {
	quietly bys hhid_p: egen b`x' = max(`x')
	quietly replace `x' = b`x'
	drop b`x'
	}

la var grew_any_W1 "household cultivated any crop in wave 1"
la var grew_any_W2 "household cultivated any crop in wave 2"
la var grew_any_W3 "household cultivated any crop in wave 3"
la var grew_maize_W1 "household cultivated any maize in wave 1"
la var grew_maize_W2 "household cultivated any maize in wave 2"
la var grew_maize_W3 "household cultivated any maize in wave 3"

la var grew_any_allwaves "household cultivated crops during all three waves"   
la var grew_maize_allwaves "household cultivated maize in all three waves" 
la var grew_maize_1and2only "household cultivated maize in W1 and W2, cultivated crops but NOT maize in W3" 
la var grew_maize_2and3only "household cultivated maize in W2 and W3, cultivated crops but NOT maize in W1" 
la var grew_maize_1only "household cultivated maize in W1 only, cultivated crops but NOT maize in W2&W3" 
la var left_farming_W2 "household cultivated maize in W1, did not cultivate any crop in W2 NOR W3" 
la var left_farming_W3 "household cultivated maize in W1 and W2, did not cultivate any crop in W3" 


**make variables that sum allocation to our crop categories by household. 
egen alloc_category_2008 = sum(allocation_2008) if allocation_2008 !=., by(hhid_p cropcat) 
bysort hhid_p cropcat: egen allplots=max(alloc_category_2008)
replace alloc_category_2008=allplots //this fills in observations for crops that were not grown during 2008
drop allplots
replace alloc_category_2008 = 0 if alloc_category_2008 ==. & grew_any_W1 ==1 //replace with 0 if the household cultivated only a different crop category during that wave
la var alloc_category_2008 "total land allocation by crop category, 2008 (need to use hh_cat_tag)"

egen alloc_category_2010 = sum(allocation_2010) if allocation_2010 !=., by(hhid_p cropcat) 
bysort hhid_p cropcat: egen allplots=max(alloc_category_2010)
replace alloc_category_2010=allplots
drop allplots
replace alloc_category_2010 = 0 if alloc_category_2010 ==. & grew_any_W2 ==1
la var alloc_category_2010 "total land allocation by crop category, 2010 (need to use hh_cat_tag)"

egen alloc_category_2012 = sum(allocation_2012) if allocation_2012 !=., by(hhid_p cropcat) 
bysort hhid_p cropcat: egen allplots=max(alloc_category_2012)
replace alloc_category_2012=allplots
drop allplots
replace alloc_category_2012 = 0 if alloc_category_2012 ==. & grew_any_W3 ==1
la var alloc_category_2012 "total land allocation by crop category, 2012 (need to use hh_cat_tag)"

**TOTAL allocation to each crop category
gen alloc_maize_2008 = .
replace alloc_maize_2008 = 0 if grew_any_W1==1
replace alloc_maize_2008 = alloc_category_2008 if cropcat ==1
bysort hhid_p: egen allplots=max(alloc_maize_2008)
replace alloc_maize_2008=allplots
drop allplots
la var alloc_maize_2008 "total land allocation TO MAIZE, 2008 (need to use hh_cat_tag)"

gen alloc_otherann_2008 = .
replace alloc_otherann_2008 = 0 if grew_any_W1==1
replace alloc_otherann_2008 = alloc_category_2008 if cropcat ==2
bysort hhid_p: egen allplots=max(alloc_otherann_2008)
replace alloc_otherann_2008=allplots
drop allplots
la var alloc_otherann_2008 "total land allocation TO OTHER ANNUAL, 2008 (need to use hh_cat_tag)"

gen alloc_perm_2008 = .
replace alloc_perm_2008 = 0 if grew_any_W1==1
replace alloc_perm_2008 = alloc_category_2008 if cropcat ==3
bysort hhid_p: egen allplots=max(alloc_perm_2008)
replace alloc_perm_2008=allplots
drop allplots
la var alloc_perm_2008 "total land allocation TO PERM/FRUIT, 2008 (need to use hh_cat_tag)"


gen alloc_maize_2010 = .
replace alloc_maize_2010 = 0 if grew_any_W2==1
replace alloc_maize_2010 = alloc_category_2010 if cropcat ==1
bysort hhid_p: egen allplots=max(alloc_maize_2010)
replace alloc_maize_2010=allplots
drop allplots
la var alloc_maize_2010 "total land allocation TO MAIZE, 2010 (need to use hh_cat_tag)"

gen alloc_otherann_2010 = .
replace alloc_otherann_2010 = 0 if grew_any_W2==1
replace alloc_otherann_2010 = alloc_category_2010 if cropcat ==2
bysort hhid_p: egen allplots=max(alloc_otherann_2010)
replace alloc_otherann_2010=allplots
drop allplots
la var alloc_otherann_2010 "total land allocation TO OTHER ANNUAL, 2010 (need to use hh_cat_tag)"

gen alloc_perm_2010 = .
replace alloc_perm_2010 = 0 if grew_any_W2==1
replace alloc_perm_2010 = alloc_category_2010 if cropcat ==3
bysort hhid_p: egen allplots=max(alloc_perm_2010)
replace alloc_perm_2010=allplots
drop allplots
la var alloc_perm_2010 "total land allocation TO PERM/FRUIT, 2010 (need to use hh_cat_tag)"


gen alloc_maize_2012 = .
replace alloc_maize_2012 = 0 if grew_any_W3==1
replace alloc_maize_2012 = alloc_category_2012 if cropcat ==1
bysort hhid_p: egen allplots=max(alloc_maize_2012)
replace alloc_maize_2012=allplots
drop allplots
la var alloc_maize_2012 "total land allocation TO MAIZE, 2012 (need to use hh_cat_tag)"

gen alloc_otherann_2012 = .
replace alloc_otherann_2012  = 0 if grew_any_W3==1
replace alloc_otherann_2012  = alloc_category_2012  if cropcat ==2
bysort hhid_p: egen allplots=max(alloc_otherann_2012 )
replace alloc_otherann_2012 =allplots
drop allplots
la var alloc_otherann_2012  "total land allocation TO OTHER ANNUAL, 2012  (need to use hh_cat_tag)"

gen alloc_perm_2012 = .
replace alloc_perm_2012 = 0 if grew_any_W3==1
replace alloc_perm_2012 = alloc_category_2012 if cropcat ==3
bysort hhid_p: egen allplots=max(alloc_perm_2012)
replace alloc_perm_2012=allplots
drop allplots
la var alloc_perm_2012 "total land allocation TO PERM/FRUIT, 2012 (need to use hh_cat_tag)"


/////////////////////now make variables for subgroups of interest to our analysis.
*dummy for whether they increased or decreased yield between each wave
gen increased_yield_arhv_2008_2010 = .
replace increased_yield_arhv_2008_2010 =1 if yield_change_arhv_2008_2010 >0 & yield_change_arhv_2008_2010!=.
replace increased_yield_arhv_2008_2010 =0 if yield_change_arhv_2008_2010 <0 //if anyone had exactly zero change we are leaving them out
la var increased_yield_arhv_2008_2010 "categorical var for yield increasers =1 yield decreasers =0"

gen increased_yield_arhv_2010_2012 = .
replace increased_yield_arhv_2010_2012 =1 if yield_change_arhv_2010_2012 >0 & yield_change_arhv_2010_2012!=.
replace increased_yield_arhv_2010_2012 =0 if yield_change_arhv_2010_2012 <0 //if anyone had exactly zero change we are leaving them out
la var increased_yield_arhv_2010_2012 "categorical var for yield increasers =1 yield decreasers =0"

gen increased_yield_arpl_2008_2010 = .
replace increased_yield_arpl_2008_2010 =1 if yield_change_arpl_2008_2010 >0 & yield_change_arpl_2008_2010!=.
replace increased_yield_arpl_2008_2010 =0 if yield_change_arpl_2008_2010 <0 //if anyone had exactly zero change we are leaving them out
la var increased_yield_arpl_2008_2010 "categorical var for yield increasers =1 yield decreasers =0"

gen increased_yield_arpl_2010_2012 = .
replace increased_yield_arpl_2010_2012 =1 if yield_change_arpl_2010_2012 >0 & yield_change_arpl_2010_2012!=.
replace increased_yield_arpl_2010_2012 =0 if yield_change_arpl_2010_2012 <0 //if anyone had exactly zero change we are leaving them out
la var increased_yield_arpl_2010_2012 "categorical var for yield increasers =1 yield decreasers =0"

//will use this var to designate subgroups of maize increasers or decreasers at the hh level
gen maize_increaser_2008_2010 =.
replace maize_increaser_2008_2010 =1 if increased_yield_arpl_2008_2010 ==1 & zaocode ==11
replace maize_increaser_2008_2010 =0 if increased_yield_arpl_2008_2010 ==0 & zaocode ==11
bysort hhid_p: egen allplots=max(maize_increaser_2008_2010)
replace maize_increaser_2008_2010=allplots
drop allplots
la var maize_increaser_2008_2010 "Household increased maize yield between 2008 and 2010"

//in order to be in our analysis, they need to have a value for maize yield for both 2008 and 2010, and have cultivated crops in 2012 too. (KPH: this may not be what we go with) 
gen maize_analysis_hh =0 //start with zero so some HH will have 0 
replace maize_analysis_hh =1 if yield_arhv_ha_2008 !=. & yield_arhv_ha_2010 !=. & zaocode ==11 & y3_hhid !=""
replace maize_analysis_hh =1 if yield_arpl_ha_2008 !=. & yield_arpl_ha_2010 !=. & zaocode ==11 & y3_hhid !=""
bysort hhid_p: egen allplots=max(maize_analysis_hh)
replace maize_analysis_hh=allplots
drop allplots
la var maize_analysis_hh "households with all necessary data for panel analysis, maize"

//note we have not filled in with zeros for hh without - will just use ==1 to tag these HH
codebook hhid_p if maize_analysis_hh ==1 


//////////////////////////////////////
//		Making additional vars 		// 
//////////////////////////////////////

//Crop sale dummies by crop category
gen sold_annual_crop_2008 = ag5a_01_2008 ==1 if ag5a_01_2008 !=.
replace sold_annual_crop_2008 = 0 if ag5a_01_2008 ==.
gen sold_annual_crop_2010 = ag5a_01_2010 ==1 if ag5a_01_2010 !=.
replace sold_annual_crop_2010 = 0 if ag5a_01_2010 ==.
gen sold_annual_crop_2012 = ag5a_01_2012 ==1 if ag5a_01_2012 !=.
replace sold_annual_crop_2012 = 0 if ag5a_01_2012 ==.
la var sold_annual_crop_2008 "crop sold by household"
la var sold_annual_crop_2010 "crop sold by household"
la var sold_annual_crop_2012 "crop sold by household"

gen quant_sold_2008 = (ag5a_02_2008)/1000 if ag5a_02_2008 !=.
replace quant_sold_2008 = 0 if sold_annual_crop_2008 ==0
gen quant_sold_2010 = (ag5a_02_2010)/1000 if ag5a_02_2010 !=.
replace quant_sold_2010 = 0 if sold_annual_crop_2010 ==0
gen quant_sold_2012 = (ag5a_02_2012)/1000 if ag5a_02_2012 !=.
replace quant_sold_2012 = 0 if sold_annual_crop_2012 ==0
la var quant_sold_2008 "(ag5a_01) quantity of crop sold, g"
la var quant_sold_2010 "(ag5a_01) quantity of crop sold, g"
la var quant_sold_2012 "(ag5a_01) quantity of crop sold, g"

gen sold_otherann_2008 = ag5a_01_2008 ==1 if ag5a_01_2008 !=. & zaocode != 11
replace sold_otherann_2008 = 0 if ag5a_01_2008 ==.
gen sold_otherann_2010 = ag5a_01_2010 ==1 if ag5a_01_2010 !=. & zaocode != 11
replace sold_otherann_2010 = 0 if ag5a_01_2010 ==.
gen sold_otherann_2012 = ag5a_01_2012 ==1 if ag5a_01_2012 !=. & zaocode != 11
replace sold_otherann_2012 = 0 if ag5a_01_2012 ==.
la var sold_otherann_2008 "(ag5a_01) household sold any annual crop besides maize"
la var sold_otherann_2010 "(ag5a_01) household sold any annual crop besides maize"
la var sold_otherann_2012 "(ag5a_01) household sold any annual crop besides maize"

gen sold_maize_2008 = ag5a_01_2008 ==1 if ag5a_01_2008 !=. & zaocode == 11
replace sold_maize_2008 = 0 if ag5a_01_2008 ==.
gen sold_maize_2010 = ag5a_01_2010 ==1 if ag5a_01_2010 !=. & zaocode == 11
replace sold_maize_2010 = 0 if ag5a_01_2010 ==.
gen sold_maize_2012 = ag5a_01_2012 ==1 if ag5a_01_2012 !=. & zaocode == 11
replace sold_maize_2012 = 0 if ag5a_01_2012 ==.
la var sold_maize_2008 "(ag5a_01) household sold maize"
la var sold_maize_2010 "(ag5a_01) household sold maize"
la var sold_maize_2012 "(ag5a_01) household sold maize"

gen sold_perm_2008 = ag7a_02_2008 ==1 if ag7a_02_2008 !=.
replace sold_perm_2008 = 1 if s7bq2_2008 ==1 
replace sold_perm_2008 = 0 if ag7a_02_2008 ==. & s7bq2_2008 ==.
gen sold_perm_2010 = ag7a_02_2010 ==1 if ag7a_02_2010 !=.
replace sold_perm_2010 = 1 if ag7b_02_2010 ==1
replace sold_perm_2010 = 0 if ag7a_02_2010 ==. & ag7b_02_2010 ==.
gen sold_perm_2012 = ag7a_02_2012 ==1 if ag7a_02_2012 !=.
replace sold_perm_2012 = 1 if ag7b_02_2012 ==1
replace sold_perm_2012 = 0 if ag7a_02_2012 ==. & ag7b_02_2012 ==.
la var sold_perm_2008 "(s7a/bq2) household sold any permanent/fruit crop"
la var sold_perm_2010 "(ag7a/b_02) household sold any permanent/fruit crop"
la var sold_perm_2012 "(ag7a/b_02) household sold any permanent/fruit crop"


//change in land allocation to crop categories between waves
gen alloc_change_maize_2008_2010 = alloc_maize_2010-alloc_maize_2008
gen alloc_change_maize_2010_2012 = alloc_maize_2012-alloc_maize_2010
la var alloc_change_maize_2008_2010 "change in land allocation to maize, 2008-2010"
la var alloc_change_maize_2010_2012 "change in land allocation to maize, 2010-2012"

gen alloc_change_otherann_2008_2010 = alloc_otherann_2010-alloc_otherann_2008
gen alloc_change_otherann_2010_2012 = alloc_otherann_2012-alloc_otherann_2010
la var alloc_change_otherann_2008_2010 "change in land allocation to annual crops besides maize, 2008-2010"
la var alloc_change_otherann_2010_2012 "change in land allocation to annual crops besides maize, 2010-2012"

gen alloc_change_perm_2008_2010 = alloc_perm_2010-alloc_perm_2008
gen alloc_change_perm_2010_2012 = alloc_perm_2012-alloc_perm_2010
la var alloc_change_perm_2008_2010 "change in land allocation to permanent/fruit crops, 2008-2010"
la var alloc_change_perm_2010_2012 "change in land allocation to permanent/fruit crops, 2010-2012"
  
local selling sold_* alloc_change_*

foreach x of varlist `selling' {
	quietly bys hhid_p: egen b`x' = max(`x')
	quietly replace `x' = b`x'
	drop b`x'
	}	


//distance crop transported for sale
gen dist_transported_avg_2008 = ag5a_19_2008 
gen dist_transported_avg_2010 = ag5a_19_x_2010 
gen dist_transported_avg_2012 = ag5a_19_2012 
la var dist_transported_avg_2008 "(ag5a_19) distance household transported crop to sale, km"
la var dist_transported_avg_2010 "(ag5a) distance household transported crop to sale, km"
la var dist_transported_avg_2012 "(ag5a_19) distance household transported crop to sale, km"

//agro-ecological zone for each year (use this instead of "zone")	
gen ageco_zone_2008 = land03_2008
gen ageco_zone_2010 = hh_envi17_2010
gen ageco_zone_2012 = land03_2012
la var ageco_zone_2008 "agroecological zone (geovariables)"
la var ageco_zone_2010 "agroecological zone (geovariables)"
la var ageco_zone_2012 "agroecological zone (geovariables)"	

///Household characteristics

gen female_hoh_2008 =.
replace female_hoh_2008 = 1 if sbq2_2008 ==2
replace female_hoh_2008 = 0 if sbq2_2008 ==1
gen female_hoh_2010 = hh_b02_2010 ==1 if hh_b02_2010 !=.
replace female_hoh_2010 = 1 if hh_b02_2010 ==2
replace female_hoh_2010 = 0 if hh_b02_2010 ==1
gen female_hoh_2012 = hh_b02_2012 ==1 if hh_b02_2012 !=.
replace female_hoh_2012 = 1 if hh_b02_2012 ==2
replace female_hoh_2012 = 0 if hh_b02_2012 ==1
la var female_hoh_2008 "(sbq2) female-headed household"
la var female_hoh_2010 "(hh_b02) female-headed household"
la var female_hoh_2012 "(hh_b02) female-headed household"
 
gen age_hoh_2008 = sbq4_2008
gen age_hoh_2010 = hh_b04_2010
gen age_hoh_2012 = hh_b04_2012
la var age_hoh_2008 "(sbq4) age of head of household"
la var age_hoh_2010 "(hh_b04) age of head of household"
la var age_hoh_2012 "(hh_b04) age of head of household"

gen educ_yrs_hoh_2008 = .
replace educ_yrs_hoh_2008 = 0 if scq2 ==2 & scq6 == . //if they said they never went to school and didn't report a highest grade completed
replace educ_yrs_hoh_2008 = 1 if scq6 == 1  //pre-primary (counting this as a year only for students who completed this grade only)
replace educ_yrs_hoh_2008 = 1 if scq6 == 11 //grade 1 of primary school 
replace educ_yrs_hoh_2008 = 2 if scq6 == 12 //grade 2
replace educ_yrs_hoh_2008 = 3 if scq6 == 13 //grade 3
replace educ_yrs_hoh_2008 = 4 if scq6 == 14 //grade 4
replace educ_yrs_hoh_2008 = 5 if scq6 == 15 //grade 5
replace educ_yrs_hoh_2008 = 6 if scq6 == 16 //grade 6
replace educ_yrs_hoh_2008 = 7 if scq6 == 17 //grade 7
replace educ_yrs_hoh_2008 = 8 if scq6 == 18 //grade 8 - according to http://www.bibl.u-szeged.hu/oseas_adsec/tanzania.htm students in TZ go to secondary school after Primary 7
replace educ_yrs_hoh_2008 = 8 if scq6 == 19 | scq6 == 20 //MS+ course or orientation secondary course: according to W3 enumerator manual this only applies in Zanzibar, according to 
//www-wds.worldbank.org/external/.../Project0Inform1nt010Appraisal0Stage.doc it is/was a full year of instruction focused on English skills - giving this an additional year of credit only for students who it was their final year
//see also http://www.moe.go.tz/index.php?option=com_content&view=article&id=1647%3Aprimary-education&catid=294%3Aprimary-education&Itemid=371

replace educ_yrs_hoh_2008 = 8 if scq6 == 21 //secondary form 1
replace educ_yrs_hoh_2008 = 9 if scq6 == 22 //secondary 2
replace educ_yrs_hoh_2008 = 10 if scq6 == 23 //secondary 3
replace educ_yrs_hoh_2008 = 11 if scq6 == 24 //secondary 4
replace educ_yrs_hoh_2008 = 12 if scq6 == 25 //O+ course (coded between F4 and F6 so assuming 1 year), see also http://www.moe.go.tz/index.php?option=com_content&view=article&id=1581&Itemid=550
replace educ_yrs_hoh_2008 = 13 if scq6 == 32 //secondary form 6
replace educ_yrs_hoh_2008 = 13 if scq6 == 33 //A levels - total 13 yrs before university
replace educ_yrs_hoh_2008 = 13 if scq6 == 34 //not sure what "diploma" is but it is coded under secondary so leaving it at 13 years

replace educ_yrs_hoh_2008 = 14 if scq6 == 41 //university 1
replace educ_yrs_hoh_2008 = 15 if scq6 == 42 //university 2
replace educ_yrs_hoh_2008 = 16 if scq6 == 43 //university 3 - here is supposedly where most people would get a baccalaureate degree
replace educ_yrs_hoh_2008 = 17 if scq6 == 44 //university 4
replace educ_yrs_hoh_2008 = 18 if scq6 == 45 //university 5+
replace educ_yrs_hoh_2008 = . if scq6 == 2 //adult education - don't know what else to do with this since they could have begun it after any number of years of primary school, leaving these as missings

gen educ_yrs_hoh_2010 = .
replace educ_yrs_hoh_2010 = 0 if hh_c03_2010 == 2 & hh_c07_2010 == . //if they said they never went to school and didn't report a highest grade completed
replace educ_yrs_hoh_2010 = 1 if hh_c07_2010 == 01  //pre-primary (counting this as a year only for students who completed this grade only)
replace educ_yrs_hoh_2010 = 1 if hh_c07_2010 == 11 //grade 1 of primary school 
replace educ_yrs_hoh_2010 = 2 if hh_c07_2010 == 12 //grade 2
replace educ_yrs_hoh_2010 = 3 if hh_c07_2010 == 13 //grade 3
replace educ_yrs_hoh_2010 = 4 if hh_c07_2010 == 14 //grade 4
replace educ_yrs_hoh_2010 = 5 if hh_c07_2010 == 15 //grade 5
replace educ_yrs_hoh_2010 = 6 if hh_c07_2010 == 16 //grade 6
replace educ_yrs_hoh_2010 = 7 if hh_c07_2010 == 17 //grade 7
replace educ_yrs_hoh_2010 = 8 if hh_c07_2010 == 18 //grade 8 - according to http://www.bibl.u-szeged.hu/oseas_adsec/tanzania.htm students in TZ go to secondary school after Primary 7
replace educ_yrs_hoh_2010 = 8 if hh_c07_2010 == 19 | hh_c07_2010 == 20 //MS+ course or orientation secondary course

replace educ_yrs_hoh_2010 = 8 if hh_c07_2010 == 21 //secondary form 1
replace educ_yrs_hoh_2010 = 9 if hh_c07_2010 == 22 //secondary 2
replace educ_yrs_hoh_2010 = 10 if hh_c07_2010 == 23 //secondary 3
replace educ_yrs_hoh_2010 = 11 if hh_c07_2010 == 24 //secondary 4
replace educ_yrs_hoh_2010 = 12 if hh_c07_2010 == 25 //O+ course (coded between F4 and F6 so assuming 1 year), see also http://www.moe.go.tz/index.php?option=com_content&view=article&id=1581&Itemid=550
replace educ_yrs_hoh_2010 = 13 if hh_c07_2010 == 32 //secondary form 6
replace educ_yrs_hoh_2010 = 13 if hh_c07_2010 == 33 //A levels - total 13 yrs before university
replace educ_yrs_hoh_2010 = 13 if hh_c07_2010 == 34 //not sure what "diploma" is but it is coded under secondary so leaving it at 13 years

replace educ_yrs_hoh_2010 = 14 if hh_c07_2010 == 41 //university 1
replace educ_yrs_hoh_2010 = 15 if hh_c07_2010 == 42 //university 2
replace educ_yrs_hoh_2010 = 16 if hh_c07_2010 == 43 //university 3 - here is supposedly where most people would get a baccalaureate degree
replace educ_yrs_hoh_2010 = 17 if hh_c07_2010 == 44 //university 4
replace educ_yrs_hoh_2010 = 18 if hh_c07_2010 == 45 //university 5+
replace educ_yrs_hoh_2010 = . if hh_c07_2010 == 02 //adult education - don't know what else to do with this since they could have begun it after any number of years of primary school

gen educ_yrs_hoh_2012 = .
replace educ_yrs_hoh_2012 = 0 if hh_c03_2012 == 2 & hh_c07_2012 == . //if they said they never went to school and didn't report a highest grade completed
replace educ_yrs_hoh_2012 = 1 if hh_c07_2012 == 01  //pre-primary (counting this as a year only for students who completed this grade only)
replace educ_yrs_hoh_2012 = 1 if hh_c07_2012 == 11 //grade 1 of primary school 
replace educ_yrs_hoh_2012 = 2 if hh_c07_2012 == 12 //grade 2
replace educ_yrs_hoh_2012 = 3 if hh_c07_2012 == 13 //grade 3
replace educ_yrs_hoh_2012 = 4 if hh_c07_2012 == 14 //grade 4
replace educ_yrs_hoh_2012 = 5 if hh_c07_2012 == 15 //grade 5
replace educ_yrs_hoh_2012 = 6 if hh_c07_2012 == 16 //grade 6
replace educ_yrs_hoh_2012 = 7 if hh_c07_2012 == 17 //grade 7
replace educ_yrs_hoh_2012 = 8 if hh_c07_2012 == 18 //grade 8 - according to http://www.bibl.u-szeged.hu/oseas_adsec/tanzania.htm students in TZ go to secondary school after Primary 7
replace educ_yrs_hoh_2012 = 8 if hh_c07_2012 == 19 | hh_c07_2012 == 20 //MS+ course or orientation secondary course

replace educ_yrs_hoh_2012 = 8 if hh_c07_2012 == 21 //secondary form 1
replace educ_yrs_hoh_2012 = 9 if hh_c07_2012 == 22 //secondary 2
replace educ_yrs_hoh_2012 = 10 if hh_c07_2012 == 23 //secondary 3
replace educ_yrs_hoh_2012 = 11 if hh_c07_2012 == 24 //secondary 4
replace educ_yrs_hoh_2012 = 12 if hh_c07_2012 == 25 //O+ course (coded between F4 and F6 so assuming 1 year), see also http://www.moe.go.tz/index.php?option=com_content&view=article&id=1581&Itemid=550
replace educ_yrs_hoh_2012 = 13 if hh_c07_2012 == 32 //secondary form 6
replace educ_yrs_hoh_2012 = 13 if hh_c07_2012 == 33 //A levels - total 13 yrs before university
replace educ_yrs_hoh_2012 = 13 if hh_c07_2012 == 34 //not sure what "diploma" is but it is coded under secondary so leaving it at 13 years

replace educ_yrs_hoh_2012 = 14 if hh_c07_2012 == 41 //university 1
replace educ_yrs_hoh_2012 = 15 if hh_c07_2012 == 42 //university 2
replace educ_yrs_hoh_2012 = 16 if hh_c07_2012 == 43 //university 3 - here is supposedly where most people would get a baccalaureate degree
replace educ_yrs_hoh_2012 = 17 if hh_c07_2012 == 44 //university 4
replace educ_yrs_hoh_2012 = 18 if hh_c07_2012 == 45 //university 5+
replace educ_yrs_hoh_2012 = . if hh_c07_2012 == 02 //adult education - don't know what else to do with this since they could have begun it after any number of years of primary school

la var educ_yrs_hoh_2008 "years of education completed by the household head"
la var educ_yrs_hoh_2010 "years of education completed by the household head"
la var educ_yrs_hoh_2012 "years of education completed by the household head"

**Generating smallholder categorial variable, <2, 2-4, 4-10, >10 ha
gen smallholder_cat_2008 =.
replace smallholder_cat_2008 = 1 if farmsize_ha_2008 <= 2
replace smallholder_cat_2008 = 2 if farmsize_ha_2008 > 2 & farmsize_ha_2008 <= 4
replace smallholder_cat_2008 = 3 if farmsize_ha_2008 > 4 & farmsize_ha_2008 <= 10
replace smallholder_cat_2008 = 4 if farmsize_ha_2008 > 10
replace smallholder_cat_2008 = . if farmsize_ha_2008 ==.

gen smallholder_cat_2010 =.
replace smallholder_cat_2010 = 1 if farmsize_ha_2010 <= 2
replace smallholder_cat_2010 = 2 if farmsize_ha_2010 > 2 & farmsize_ha_2010 <= 4
replace smallholder_cat_2010 = 3 if farmsize_ha_2010 > 4 & farmsize_ha_2010 <= 10
replace smallholder_cat_2010 = 4 if farmsize_ha_2010 > 10
replace smallholder_cat_2010 = . if farmsize_ha_2010 ==.

gen smallholder_cat_2012 =.
replace smallholder_cat_2012 = 1 if farmsize_ha_2012 <= 2
replace smallholder_cat_2012 = 2 if farmsize_ha_2012 > 2 & farmsize_ha_2012 <= 4
replace smallholder_cat_2012 = 3 if farmsize_ha_2012 > 4 & farmsize_ha_2012 <= 10
replace smallholder_cat_2012 = 4 if farmsize_ha_2012 > 10
replace smallholder_cat_2012 = . if farmsize_ha_2012 ==.

la var smallholder_cat_2008 "cat var of landholding size, <=2 ha (1), >2-4 ha (2), >4-10 ha (3), >10 ha (4)"
la var smallholder_cat_2010 "cat var of landholding size, <=2 ha (1), >2-4 ha (2), >4-10 ha (3), >10 ha (4)"
la var smallholder_cat_2012 "cat var of landholding size, <=2 ha (1), >2-4 ha (2), >4-10 ha (3), >10 ha (4)"



////////////////////////////////////////////////////////////
**          	Reshaping/Saving for Shiny App     		  ** 
////////////////////////////////////////////////////////////

//rename some variables to be able to reshape, this will let us facet by year in the Shiny app
ren hh_a02_1_2008 district_2008
ren hh_a03_1_2008 ward_2008
ren plot01_2010 district_2010
ren hh_a02_1_2010 ward_2010
ren ag_a02_1_2012 district_2012
ren ag_a03_1_2012 ward_2012
ren ag_a04_1_2012 ea_2012

ren dist03_2008 dist_market_2008
ren dist03_2010 dist_market_2010
ren dist03_2012 dist_market_2012
ren plot01_2008 dist_road_2008
ren dist01_2010 dist_road_2010
ren dist01_2012 dist_road_2012


//lists of vars we want to keep for this exported dataset 
global identifiers hhid_p zaocode panelweight panelcluster panelstrata 

global categoricals smallholder_cat_* grew_fruit_* grew_perm_* grew_annual_* sold_perm_* sold_otherann_* sold_maize_* ageco_zone_* female_hoh_* maize_increaser_* maize_analysis_hh splitoff_* experienced_splitoff* hh_moved_* ///
district_* region_* ageco_zone* grew_any_allwaves grew_maize_1and2only grew_maize_2and3only grew_maize_1only left_farming_W2 left_farming_W3 plot_irrigated* org_fert* inorg_fert* pest_herb_usage* landuse_ic_ap* ///

global continuous farmsize_ha_* arpl_crop_* arhv_crop_* ///
tot_hh_labor_days_* tot_hired_labor_days_* harv_quant_kg_* quant_sold_* dist_transported_avg_* hh_size_* dist_road_* dist_market_* age_hoh_* educ_yrs_hoh_* cons_tot_* cons_own_* ///
yield_arhv_ha_* yield_arpl_ha_* alloc_maize_* alloc_otherann_* alloc_perm_* alloc_change_* shadowpricecluster_lrs_* shadowpriceraw_lrs_* ///
yield_change_arhv_2008_2010 yield_change_arhv_2010_2012 yield_change_arpl_2008_2010 yield_change_arpl_2010_2012

keep $identifiers $categoricals $continuous

**Ensure all HOUSEHOLD LEVEL variables are bysorted to household level before dropping non-maize crops** 
//note: if we wanted plot level variables to represent behavior on maize plots only, instead of household-wide, we would exclude them from the list (ex org_fert: used organic fert on any plot vs. used organic fert on any maize plot).
local household smallholder_cat_* grew_fruit_* grew_perm_* grew_annual_* sold_perm_* sold_otherann_* sold_maize_* female_hoh_* maize_increaser_* maize_analysis_hh splitoff_* experienced_splitoff* hh_moved_* ///
grew_any_allwaves grew_maize_1and2only grew_maize_2and3only grew_maize_1only left_farming_W2 left_farming_W3 plot_irrigated* org_fert* inorg_fert* pest_herb_usage* landuse_ic_ap* ///
farmsize_ha_* tot_hh_labor_days_* tot_hired_labor_days_* hh_size_* dist_road_* dist_market_* age_hoh_* educ_yrs_hoh_* cons_tot_* cons_own_* ///
alloc_maize_* alloc_otherann_* alloc_perm_* alloc_change_* shadowpricecluster_lrs_* shadowpriceraw_lrs_* ///

foreach x of varlist `household' {
	quietly bys hhid_p: egen b`x' = max(`x')
	quietly replace `x' = b`x'
	drop b`x'
	}

//maize observations only: one obs per hh
drop if zaocode != 11

//reshape: dataset will now be at the level "hhid_p year"
global stubs region_@ district_@ splitoff_child_@ experienced_splitoff_@ splitoff_parent_@ hh_moved_@ smallholder_cat_@ ///
grew_fruit_@ grew_perm_@ grew_annual_@ sold_perm_@ sold_otherann_@ sold_maize_@ ageco_zone_@ female_hoh_@ maize_increaser_2008_@ ///
farmsize_ha_@ arpl_crop_@ arhv_crop_@ harv_quant_kg_@ quant_sold_@ dist_transported_avg_@ hh_size_@ dist_road_@ dist_market_@ age_hoh_@ educ_yrs_hoh_@ ///
cons_tot_greenmaize_kg_@ cons_tot_maizegrain_kg_@ cons_tot_maizeflour_kg_@ cons_own_greenmaize_kg_@ cons_own_maizegrain_kg_@ cons_own_maizeflour_kg_@ ///
yield_arhv_ha_@ yield_arpl_ha_@ alloc_maize_@ alloc_otherann_@ alloc_perm_@ shadowpricecluster_lrs_@ shadowpriceraw_lrs_@ ///
tot_hh_labor_days_@ tot_hired_labor_days_@ alloc_change_maize_2008_@ alloc_change_maize_2010_@ alloc_change_otherann_2008_@ alloc_change_otherann_2010_@ alloc_change_perm_2008_@ alloc_change_perm_2010_@ ///
plot_irrigated_@ org_fert_@ inorg_fert_@ pest_herb_usage_@ landuse_ic_ap_@ yield_change_arhv_2008_@ yield_change_arhv_2010_@ yield_change_arpl_2008_@ yield_change_arpl_2010_@

reshape long $stubs, i(hhid_p) j(year) 

isid hhid_p year

//rename vars with change over time to be more clear
ren maize_increaser_2008 maize_increaser_2008_2010
ren alloc_change_maize_2010_ alloc_change_maize_2010_2012
ren alloc_change_otherann_2010_ alloc_change_otherann_2010_2012
ren alloc_change_perm_2010_ alloc_change_perm_2010_2012
ren alloc_change_maize_2008_ alloc_change_maize_2008_2010
ren alloc_change_otherann_2008_ alloc_change_otherann_2008_2010
ren alloc_change_perm_2008_ alloc_change_perm_2008_2010

ren yield_change_arhv_2008_ yield_change_arhv_2008_2010 
ren yield_change_arhv_2010_ yield_change_arhv_2010_2012 
ren yield_change_arpl_2008_ yield_change_arpl_2008_2010 
ren yield_change_arpl_2010_ yield_change_arpl_2010_2012

//relabel variables that lost their labels
la var year "year of survey (j var for reshape)"
la var region_ "region"
la var district_ "district"
la var quant_sold_ "quantity of crop sold, kg"
la var sold_maize_ "household sold maize"
la var sold_perm_ "household sold any permanent/fruit crop"
la var dist_transported_avg_ "distance household transported crop to sale, km"
la var ageco_zone_ "agroecological zone (geovariables)"
la var female_hoh_ "female-headed household"
la var age_hoh_ "age of head of household"
la var educ_yrs_hoh_ "years of education completed by the household head"
la var hh_size "count (indid): number of household members"
la var splitoff_child_ "hh is a 'child' splitoff"
la var splitoff_parent_ "hh is a 'parent' that experienced a split before this wave"
la var experienced_splitoff_ "hh experienced splitoff before this wave - original OR child"
la var hh_moved_ "household moved before wave"
la var grew_fruit "household grew any fruit crops"
la var grew_perm "household grew any permanent crops"
la var grew_annual "hh grew annual crops"
la var arpl_crop "sum of total area planted for this crop, by household"
la var arhv_crop "sum of area harvested for annual crop, by household"
la var tot_hh_labor_days_ "total number of HH labor days on farm"
la var tot_hired_labor_days_ "total number of hired labor days"
la var harv_quant_kg "sum of harvest quantity for annual crop, by household"
la var shadowpricecluster_lrs "Sold unit value price (TSH) clustered median (smallest geo unit w/ >=10 price values)"
la var shadowpriceraw_lrs "Sold unit value price (TSH) is reported HH value, if MISSING price is clustered median" 
la var farmsize_ha "total farm area measure, ha - GPS-based if they have one, farmer-report if not"
la var alloc_maize_ "total land allocation to maize"
la var alloc_otherann_  "total land allocation to annual crops besides maize"
la var alloc_perm_ "total land allocation to permanent/fruit crops"
la var alloc_change_maize_2008_2010 "change in land allocation to maize, 2008-2010"
la var alloc_change_maize_2010_2012 "change in land allocation to maize, 2010-2012"
la var alloc_change_otherann_2008_2010 "change in land allocation to annual crops besides maize, 2008-2010"
la var alloc_change_otherann_2010_2012 "change in land allocation to annual crops besides maize, 2010-2012"
la var alloc_change_perm_2008_2010 "change in land allocation to permanent/fruit crops, 2008-2010"
la var alloc_change_perm_2010_2012 "change in land allocation to permanent/fruit crops, 2010-2012"
la var yield_arhv_ha_ "(harv_quant/area_harvested_ha) annual crop yield by area harvested kg/ha (GPS)"
la var yield_arpl_ha_ "(harv_quant/area_planted_ha) annual crop yield by area planted kg/ha (GPS)"
la var sold_otherann_ "household sold any annual crop besides maize"
la var yield_change_arhv_2008_2010 "change in yield by area harvested from 2008-2010, annual crops" 
la var yield_change_arhv_2010_2012 "change in yield by area harvested from 2010-2012, annual crops" 
la var yield_change_arpl_2008_2010 "change in yield by area planted from 2008-2010, annual crops" 
la var yield_change_arpl_2010_2012 "change in yield by area planted from 2010-2012, annual crops"
la var dist_market_ "hh distance to nearest major market (FEWSNET key market centers) (geovars)"
la var dist_road_ "hh distance to nearest trunk road (as defined by TANROADS) (geovars)"
la var cons_tot_greenmaize_kg "total household weekly consumption of green maize, kg"
la var cons_tot_maizegrain_kg "total household weekly consumption of maize grain, kg"
la var cons_tot_maizeflour_kg "total household weekly consumption of maize flour, kg"
la var cons_own_greenmaize_kg "household weekly consumption from own production of green maize, kg"
la var cons_own_maizegrain_kg "household weekly consumption from own production of maize grain, kg"
la var cons_own_maizeflour_kg "household weekly consumption from own production of maize flour, kg"
la var maize_increaser_2008_2010 "Household increased maize yield between 2008 and 2010"
label var landuse_ic_ap "HH had any intercropped plot, any crop"
label var plot_irrigated "HH irrigated any plot"
label var org_fert "HH used organic fertilizer on any plot"
label var inorg_fert "HH used inorganic fertilizer on any plot"
label var pest_herb_usage "HH used pesticides or herbicides on any plot"
la var smallholder_cat_ "cat var of landholding size, <=2 ha (1), >2-4 ha (2), >4-10 ha (3), >10 ha (4)"


//drop the vars we don't need for the app
drop hhid_p zaocode panel*
//save a version 12 .dta so R can read it (another option is to save, then use "readstata13" package instead of "foreign")
saveold "$merge\shiny_data.dta", version(12) replace

