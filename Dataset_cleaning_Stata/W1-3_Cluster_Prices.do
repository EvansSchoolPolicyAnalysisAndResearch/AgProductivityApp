***************************************************************************************************************
*Title/Purpose of Do File: Tanzania LSMS-ISA (2008, 2010, 2012) - Ag survey - DERIVING CLUSTERED MAIZE PRICES (Shiny agricultural productivity app)
*Author(s): Katie Panhorst Harris
*Date started: 6/6/16
*Date completed: 6/15/16

*CHECKED BY: Maggie Beetstra
*DATE: 6/14/16
***************************************************************************************************************

*This file is to be run after W1_Ag_merge, W2_Ag_merge, and W3_Ag_merge, but before Three-panel_merge.

*These shadow prices use the median sold price unit value of the smallest geographical unit in which there were at least ten HHs that DID sell the crop of interest.
*If there were at least 10 crop price observations at the EA level, the price is clustered there for that crop. IF not, the calculation goes up a level (to Ward), etc.
*Therefore the medians are clustered at different geographical units among crops based on the number of locally available observations.
*Survey weights need to be set to get weighted medians. Therefore, Shadow price creation loops for 2008 (using 2008 weights) are listed first followed by 2010 (using 2010 weights).

* OUTLINE OF CODE
* first the code is divided by years (years are done separately because they have different weights)
* Within each season, there are five loops at different geographic levels starting with EA, WARD, REGION, ZONE, and NATIONAL

//Start with .do file saved in W1_Ag_Merge, etc.
clear
global input "FILEPATH\Merged Data Shiny" //Reset to where you have been saving output data 

************
** WAVE 1 **
************

clear
use "$input\2008 data\Merged Data Shiny\wave1_merged_shiny.dta"
tab ag5a_01_2008 if zaocode ==11 & wave1 ==1, missing //58 hh did not answer the question for maize, 374 sold, 962 did not
{
//Step 1: get rid of all obs that are not maize
keep if zaocode ==11

//Step 2: generate HH-level price variable: value (TSH) / quantity (kg)
count if ag5a_01_2008 == 1 & ag5a_02_2008 ==.
count if ag5a_01_2008 == 1 & ag5a_03_2008 ==.
//missing values do not look like a problem for the hh that did sell

gen price_kg_tsh_hh = ag5a_03_2008/ag5a_02_2008 
la var price_kg_tsh_hh "(ag5a_02-03) crop price per kilo received by household, TZ shillings"
sort ea_id_2008 

*br
**not all HH have ea_id_2008, this appears to be in the geovariables. It is equivalent to the first 10 digits of hhid_2008. 
**make a step variable
gen ea_step = substr(hhid_2008,1,10) //start with the first digit and take the first 10 digits
replace ea_id_2008 = ea_step if ea_id_2008 =="" //replace the 88 obs missing an ea_id
sort ea_id_2008 //most EAs do not have 10 observations

tab region ag5a_01
sort region_2008 hh_a02_1_2008 

*Generate variable for zone
generate zone =.
recode zone .=1 if (strataid == 1 | strataid == 2)
recode zone .=2 if (strataid == 3 | strataid == 4)
recode zone .=3 if (strataid == 5 | strataid == 6)
recode zone .=4 if (strataid == 7 | strataid == 8)
recode zone .=5 if (strataid == 9 | strataid == 10)
recode zone .=6 if (strataid == 11 | strataid == 12)
recode zone .=7 if (strataid == 13 | strataid == 14)
recode zone .=8 if (strataid == 15 | strataid == 16)

label define zone1 1 "Central" 2 "Eastern" 3 "Southern Highlands" 4 "Lake" 5 "Northern" 6 "Southern" 7 "Western" 8 "Zanzibar"
label values zone zone1

ren region_2008 region
ren ea_id_2008 ea //otherwise EAs are not uniquely identified

//ward has either 1 or 2 digits now, make all 2 digits
tostring hh_a03_1_2008, gen(ward_string)
gen ward_temp = "0" + ward_string if hh_a03_1_2008 <10
replace ward_string=ward_temp if hh_a03_1_2008 <10

//district has 1 digit always, just make string
tostring hh_a02_1_2008, gen(district_string)

//region has 1 or 2 digits, make all 2 digit
tostring region, gen(region_string)
gen region_temp = "0" + region_string if region <10
replace region_string=region_temp if region<10

* make unique variables at each geographic level
//district: region+district
gen district = region_string + district_string
la var district "unique district ID (created, region-district)"

//ward: region+district+ward
gen ward = region_string + district_string + ward_string
la var ward "unique ward ID (created, region-district-ward)"

//EA: already made EA ID
la var ea "unique EA ID (created, region-district-ward-ea)"

//check results
codebook district //117
codebook ward //248
codebook ea //263


//////////////////////////////////////////////////////////////////////////////////////////////////////////////
********************************************* Set Survey Weights *********************************************
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

**Set Survey for 2008 Weights***
svyset clusterid [pweight=hh_weight_2008], strata(strataid) vce(linearized) singleunit(centered) || _n

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
************************************ 2008 Shadow Price Creation & Loops **************************************
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

*Create clustered sold price unit value medians for smallest geographic levels with at least 10 sold price values by crop
*Geographic levels: 1)Enumeration Area (EA) 2)Ward 3) District 4)Region 5)Zone 6)National
*Dummy variables for source of price countain the word 'source' on the variable name followed by geographic level or 'self' for self-reported

*Create dummy variables to keep track of which level the price came from, first self-reported, then geography loop.
gen shadowpriceraw_source_self = 0
replace shadowpriceraw_source_self = 1 if price_kg_tsh_hh!=. 
lab var shadowpriceraw_source_self "Shadow price raw created at self-reported level dummy"

* create nonsense variables for the sole purpose of running loops with these var names
gen clstr=0
gen raw=0
gen nat=0

* create series of geographic level dummies to keep track of which level the shadow price came from
* variables are dummies, therefore assign only zero values and no missing values (one dummy spans all seasons, therefore missing values not possible)
local values "clstr raw"
local geog "ea ward district region zone nat"
foreach x of varlist `values'{
	foreach y of varlist `geog'{
	gen shadowprice`x'_source_`y' = 0
	lab var shadowprice`x'_source_`y' "Shadow price `x' created at `y' level dummy"
	}
}

* drop nonsense variables as they are no longer needed
drop clstr raw nat

* make a variable for each value of each geographic level
tab zone, generate(x_zone)
tab region, generate(x_region)
tab district, gen(x_district)
tab ward, generate(x_ward)
tab ea, generate(x_ea)

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
******************************************** Create Globals **************************************************
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
*Create global lists of the geographical unit dummies in which median prices will be clustered
global zones x_zone*
global regions x_reg*
global districts x_dist*
global wards x_ward*
global eas x_ea*

///////////////// LRS Crops //////////////
*Generate general shadow price variables to be used for output value creation below.
*generate clustered prices based on median sold prices

gen shadowpricecluster_lrs=.
label var shadowpricecluster_lrs "Sold unit value price clustered median (smallest geo unit w/ >=10 price values)"
*generate shadow price variable equal to sold values when they are not missing. If MISSING, future commands will insert clustered median value (created below in loops) of lowest geographical unit with 10 or more observations"
gen shadowpriceraw_lrs=.
replace shadowpriceraw_lrs = price_kg_tsh_hh if price_kg_tsh_hh!=.
label var shadowpriceraw_lrs "Sold unit value price is reported HH value, if MISSING price is clustered median" 

******** EA ********
gen shadowpriceea_lrs=.
label var shadowpriceea_lrs "EA weighted median sold unit value price if at least 10 values present"

foreach Y of varlist $eas {
*foreach X of varlist $lrs {
quietly count if `Y'==1 & price_kg_tsh_hh!=. & (ag5a_01 !=.) 
	if `r(N)'>9 {
	_pctile price_kg_tsh_hh if `Y'==1 [pweight=hh_weight_2008], p(50)
	
	quietly replace shadowpriceclstr_source_ea = 1 if r(r1)!=. & `Y'==1 
	quietly replace shadowpriceraw_source_ea = 1 if r(r1)!=. & `Y'==1 & shadowpriceraw_source_self==0
	
	quietly replace shadowpriceea_lrs = r(r1) if `Y'==1 
	quietly replace shadowpricecluster_lrs = r(r1) if `Y'==1 
	quietly replace shadowpriceraw_lrs = r(r1) if `Y'==1 & shadowpriceraw_lrs==.
	}
}


******** Ward ********
gen shadowpriceward_lrs=.
label var shadowpriceward_lrs "Ward weighted median sold unit value price if at least 10 values present"

foreach Y of varlist $wards {
quietly count if `Y'==1 & price_kg_tsh_hh!=. & (ag5a_01 !=.) 
		if `r(N)'>9 {
	_pctile price_kg_tsh_hh if `Y'==1 [pweight=hh_weight_2008], p(50)
	
	quietly replace shadowpriceclstr_source_ward = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_ea==0
	quietly replace shadowpriceraw_source_ward = 1 if r(r1)!=. & `Y'==1 & shadowpriceraw_source_ea==0 & shadowpriceraw_source_self==0
	
	quietly replace shadowpriceward_lrs = r(r1) if `Y'==1 
	quietly replace shadowpricecluster_lrs = r(r1) if `Y'==1 & shadowpricecluster_lrs==.
	quietly replace shadowpriceraw_lrs = r(r1) if `Y'==1 & shadowpriceraw_lrs==.
	}
}

******** District ********
gen shadowpricedistrict_lrs=.
label var shadowpricedistrict_lrs "district weighted median sold unit value price if at least 10 values present"

foreach Y of varlist $districts {
quietly count if `Y'==1 & price_kg_tsh_hh!=. & (ag5a_01 !=.) 
		if `r(N)'>9 {
	_pctile price_kg_tsh_hh if `Y'==1 [pweight=hh_weight_2008], p(50)
	
	quietly replace shadowpriceclstr_source_district = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_ward==0 & shadowpriceclstr_source_ea==0
	quietly replace shadowpriceraw_source_district = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_ward==0 & shadowpriceraw_source_ea==0 & shadowpriceraw_source_self==0
	
	quietly replace shadowpricedistrict_lrs = r(r1) if `Y'==1 
	quietly replace shadowpricecluster_lrs = r(r1) if `Y'==1 & shadowpricecluster_lrs==.
	quietly replace shadowpriceraw_lrs = r(r1) if `Y'==1 & shadowpriceraw_lrs==.
	}
}


******** Region ********
gen shadowpriceregion_lrs=.
label var shadowpriceregion_lrs "Region weighted median sold unit value price if at least 10 values present"

foreach Y of varlist $regions {
quietly count if `Y'==1 & price_kg_tsh_hh!=. & (ag5a_01 !=.) 
		if `r(N)'>9 {
	_pctile price_kg_tsh_hh if `Y'==1 [pweight=hh_weight_2008], p(50)
	
	quietly replace shadowpriceclstr_source_region = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_district==0 & shadowpriceclstr_source_ward==0 & shadowpriceclstr_source_ea==0
	quietly replace shadowpriceraw_source_region = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_district==0 & shadowpriceraw_source_ward==0 & shadowpriceraw_source_ea==0 & shadowpriceraw_source_self==0
	
	quietly replace shadowpriceregion_lrs = r(r1) if `Y'==1 
	quietly replace shadowpricecluster_lrs = r(r1) if `Y'==1 & shadowpricecluster_lrs==.
	quietly replace shadowpriceraw_lrs = r(r1) if `Y'==1 & shadowpriceraw_lrs==.
	}
}



******** Zone ********
gen shadowpricezone_lrs=.
label var shadowpricezone_lrs "Zone weighted median sold unit value price if at least 10 values present"

foreach Y of varlist $zones {
quietly count if `Y'==1 & price_kg_tsh_hh!=. & (ag5a_01 !=.) 
		if `r(N)'>9 {
	_pctile price_kg_tsh_hh if `Y'==1 [pweight=hh_weight_2008], p(50)
	
	quietly replace shadowpriceclstr_source_zone = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_region==0 & shadowpriceclstr_source_district==0 & shadowpriceclstr_source_ward==0 & shadowpriceclstr_source_ea==0
	quietly replace shadowpriceraw_source_zone = 1 if r(r1)!=. & `Y'==1 & shadowpriceraw_source_region==0 & shadowpriceclstr_source_district==0 & shadowpriceraw_source_ward==0 & shadowpriceraw_source_ea==0 & shadowpriceraw_source_self==0
	
	quietly replace shadowpricezone_lrs = r(r1) if `Y'==1 
	quietly replace shadowpricecluster_lrs = r(r1) if `Y'==1 & shadowpricecluster_lrs==.
	quietly replace shadowpriceraw_lrs = r(r1) if `Y'==1 & shadowpriceraw_lrs==.
	}
}
	

******** National ********
gen shadowpricetz_lrs=.
label var shadowpricetz_lrs "National weighted median sold unit value price if at least 10 values present"

quietly count if price_kg_tsh_hh!=. & (ag5a_01 !=.)
	if `r(N)'>0 {
	_pctile price_kg_tsh_hh [pweight=hh_weight_2008], p(50)

	replace shadowpriceclstr_source_nat = 1 if r(r1)!=. & shadowpriceclstr_source_zone==0 & shadowpriceclstr_source_region==0 & shadowpriceclstr_source_district==0 & shadowpriceclstr_source_ward==0 & shadowpriceclstr_source_ea==0
	replace shadowpriceraw_source_nat = 1 if r(r1)!=. & shadowpriceraw_source_zone==0 & shadowpriceraw_source_region==0 & shadowpriceclstr_source_district==0 & shadowpriceraw_source_ward==0 & shadowpriceraw_source_ea==0 & shadowpriceraw_source_self==0
	
	replace shadowpricetz_lrs = r(r1)
	replace shadowpricecluster_lrs = r(r1) if shadowpricecluster_lrs==.
	replace shadowpriceraw_lrs = r(r1) if shadowpriceraw_lrs==.
	}



***** Convert series of dummy vars into one categorical variable *****
gen shadowpriceclstr_source=.
label var shadowpriceclstr_source "Categorical variable of what level clustered shadow price comes from"
replace shadowpriceclstr_source=1 if shadowpriceclstr_source_ea==1
replace shadowpriceclstr_source=2 if shadowpriceclstr_source_ward==1
replace shadowpriceclstr_source=3 if shadowpriceclstr_source_district==1
replace shadowpriceclstr_source=4 if shadowpriceclstr_source_region==1
replace shadowpriceclstr_source=5 if shadowpriceclstr_source_zone==1
replace shadowpriceclstr_source=6 if shadowpriceclstr_source_nat==1

gen shadowpriceraw_source=.
label var shadowpriceraw_source "Categorical variable of what level raw price comes from"
replace shadowpriceraw_source=1 if shadowpriceraw_source_ea==1
replace shadowpriceraw_source=2 if shadowpriceraw_source_ward==1
replace shadowpriceraw_source=3 if shadowpriceraw_source_district==1
replace shadowpriceraw_source=4 if shadowpriceraw_source_region==1
replace shadowpriceraw_source=5 if shadowpriceraw_source_zone==1
replace shadowpriceraw_source=6 if shadowpriceraw_source_nat==1
replace shadowpriceraw_source=7 if shadowpriceraw_source_self==1

label define source1 1 "EA" 2 "Ward" 3 "District" 4 "Region" 5 "Zone" 6 "National" 7 "Self Reported"
label values shadowpriceclstr_source shadowpriceraw_source source1

*Only keep identifiers and new variables to merge back in
keep hhid_p zaocode shadowpricecluster_lrs shadowpriceraw_lrs shadowpriceclstr_source shadowpriceraw_source harv_value_tsh

**add _2008 to the end of each var
foreach x of varlist *{
rename `x' `x'_2008
}

//reversing these renames, because we need to merge on them
rename zaocode_2008 zaocode
rename hhid_p_2008 hhid_p

*Save to merge back into analysis dataset
save "$input\2008 data\Merged Data Shiny\W1_shadowprice.dta", replace
}

************
** WAVE 2 **
************
{
clear
use "$input\2010 data\Merged Data Shiny\W2_merged_shiny"
tab ag5a_01 if zaocode ==11 & wave2 ==1, missing //9 hh did not answer the question for maize, 502 sold, 1059 did not

//Step 1: get rid of all obs that are not maize
keep if zaocode ==11

//Step 2: generate HH-level price variable: value (TSH) / quantity (kg)
count if ag5a_01 == 1 & ag5a_02 ==.
count if ag5a_01 == 1 & ag5a_03 ==.
//missing values do not look like a problem for the hh that did sell

** Calculate HH level price: value/quantity
gen price_kg_tsh_hh = ag5a_03/ag5a_02
la var price_kg_tsh_hh "(ag5a_02-03) crop price per kilo received by household, TZ shillings"

*Generate variable for zone
generate zone =.
recode zone .=1 if (region == 1 | region == 13)
recode zone .=2 if (region == 5 | region == 6 | region == 7)
recode zone .=3 if (region == 11 | region == 12 | region == 15)
recode zone .=4 if (region == 18 | region == 19 | region == 20)
recode zone .=5 if (region == 2 | region == 3 | region == 4 | region == 21)
recode zone .=6 if (region == 8 | region == 9 | region == 10)
recode zone .=7 if (region == 14 | region == 16 | region == 17)
recode zone .=8 if (region == 51 | region == 52 | region == 53 | region == 54 | region == 55)

label define zone1 1 "Central" 2 "Eastern" 3 "Southern Highlands" 4 "Lake" 5 "Northern" 6 "Southern" 7 "Western" 8 "Zanzibar"
label values zone zone1

ren region_2010 region

* ward and locality values change between 2008 and 2010. In 2008, two separate variables. In 2010, locality concatenated onto the end of ward.
* 35 unique ward values in 2008, 103 unique ward values in 2010 because "locality" digit was put at the end of the ward value in 2010
* to keep values consistent across years, disaggregate 2010 ward variable into its ward and locality components
* to separate digits in the 2010 ward variable, it needs to be a string variable
tostring hh_a02_1, gen(ward_pp) 
* keep only the last digit to get the locality #
gen locality_p=substr(ward_pp, -1,.)
destring locality_p, gen(locality)
* keep only the first digit to get the ward # for wards under '10' 
gen ward_string=substr(ward_pp, 1, 1) if hh_a02_1<100
* keep only the first 2 digits to get the ward # for wards over '10'
replace ward_string=substr(ward_pp, 1, 2) if hh_a02_1>100 

//ward has either 1 or 2 digits now, make all 2 digits
gen ward_temp = "0" + ward_string if hh_a02_1 <100
replace ward_string=ward_temp if hh_a02_1<100

//district has 1 digit always, just make string
tostring plot01, gen(district_string)

//region has 1 or 2 digits, make all 2 digit
tostring region, gen(region_string)
gen region_temp = "0" + region_string if region <10
replace region_string=region_temp if region<10

//EA has 1-3 digits, but we don't really care if these numbers are all the same length, so just tack it on the end and we will have a unique eaid
tostring ea_2010, gen(ea_string)

* make unique variables at each geographic level
//district: region+district
gen district = region_string + district_string
la var district "unique district ID (created, region-district)"

//ward: region+district+ward
gen ward = region_string + district_string + ward_string
la var ward "unique ward ID (created, region-district-ward)"

//EA: region+district+ward+EA
gen ea = region_string + district_string + ward_string + ea_string
la var ea "unique EA ID (created, region-district-ward-ea)"

//check results
codebook district //120
codebook ward //410
codebook ea //802




//////////////////////////////////////////////////////////////////////////////////////////////////////////////
********************************************* Set Survey Weights *********************************************
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

**Set Survey for 2010 Weights*** 
svyset clusterid [pweight=y2_weight_2010], strata(strataid) vce(linearized) singleunit(centered) || _n

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
************************************ 2010 Shadow Price Creation & Loops **************************************
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

*Create clustered sold price unit value medians for smallest geographic levels with at least 10 sold price values by crop
*Geographic levels: 1)Enumeration Area (EA) 2)Ward 3) District 4)Region 5)Zone 6)National
*Dummy variables for source of price countain the word 'source' on the variable name followed by geographic level or 'self' for self-reported

*Create dummy variables to keep track of which level the price came from, first self-reported, then geography loop.

gen shadowpriceraw_source_self = 0
replace shadowpriceraw_source_self = 1 if price_kg_tsh_hh!=. 
lab var shadowpriceraw_source_self "Shadow price raw created at self-reported level dummy"

* create nonsense variables for the sole purpose of running loops with these var names
gen clstr=0
gen raw=0
gen nat=0

* create series of geographic level dummies to keep track of which level the shadow price came from
* variables are dummies, therefore assign only zero values and no missing values (one dummy spans all seasons, therefore missing values not possible)
local values "clstr raw"
local geog "ea ward district region zone nat"
foreach x of varlist `values'{
	foreach y of varlist `geog'{
	gen shadowprice`x'_source_`y' = 0
	lab var shadowprice`x'_source_`y' "Shadow price `x' created at `y' level dummy"
	}
}

* drop nonsense variables as they are no longer needed
drop clstr raw nat

* make a variable for each value of each geographic level
tab zone, generate(x_zone)
tab region, generate(x_region)
tab district, gen(x_district)
tab ward, generate(x_ward)
tab ea, generate(x_ea)

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
******************************************** Create Globals **************************************************
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
*Create global lists of the geographical unit dummies in which median prices will be clustered
global zones x_zone*
global regions x_reg*
global districts x_dist*
global wards x_ward*
global eas x_ea*


///////////////// LRS Crops //////////////
*Generate general shadow price variables to be used for output value creation below.
*generate clustered prices based on median sold prices

gen shadowpricecluster_lrs=.
label var shadowpricecluster_lrs "Sold unit value price clustered median (smallest geo unit w/ >=10 price values)"
*generate shadow price variable equal to sold values when they are not missing. If MISSING, future commands will insert clustered median value (created below in loops) of lowest geographical unit with 10 or more observations"
//the conversion from TSH to international $ from 2010 at this website: http://data.worldbank.org/indicator/PA.NUS.PPP?locations=TZ 
gen shadowpriceraw_lrs=.
replace shadowpriceraw_lrs = (price_kg_tsh_hh)/478.071 if price_kg_tsh_hh!=.
label var shadowpriceraw_lrs "Sold unit value price is reported HH value, if MISSING price is clustered median, international $" 

******** EA ********
gen shadowpriceea_lrs=.
label var shadowpriceea_lrs "EA weighted median sold unit value price if at least 10 values present"

foreach Y of varlist $eas {
*foreach X of varlist $lrs {
quietly count if `Y'==1 & price_kg_tsh_hh!=. & (ag5a_01 !=.) 
	if `r(N)'>9 {
	_pctile price_kg_tsh_hh if `Y'==1 [pweight=y2_weight_2010], p(50)
	
	quietly replace shadowpriceclstr_source_ea = 1 if r(r1)!=. & `Y'==1 
	quietly replace shadowpriceraw_source_ea = 1 if r(r1)!=. & `Y'==1 & shadowpriceraw_source_self==0
	
	quietly replace shadowpriceea_lrs = r(r1) if `Y'==1 
	quietly replace shadowpricecluster_lrs = r(r1) if `Y'==1 
	quietly replace shadowpriceraw_lrs = r(r1) if `Y'==1 & shadowpriceraw_lrs==.
	}
}


******** Ward ********
gen shadowpriceward_lrs=.
label var shadowpriceward_lrs "Ward weighted median sold unit value price if at least 10 values present"

foreach Y of varlist $wards {
quietly count if `Y'==1 & price_kg_tsh_hh!=. & (ag5a_01 !=.) 
		if `r(N)'>9 {
	_pctile price_kg_tsh_hh if `Y'==1 [pweight=y2_weight_2010], p(50)
	
	quietly replace shadowpriceclstr_source_ward = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_ea==0
	quietly replace shadowpriceraw_source_ward = 1 if r(r1)!=. & `Y'==1 & shadowpriceraw_source_ea==0 & shadowpriceraw_source_self==0
	
	quietly replace shadowpriceward_lrs = r(r1) if `Y'==1 
	quietly replace shadowpricecluster_lrs = r(r1) if `Y'==1 & shadowpricecluster_lrs==.
	quietly replace shadowpriceraw_lrs = r(r1) if `Y'==1 & shadowpriceraw_lrs==.
	}
}

******** District ********
gen shadowpricedistrict_lrs=.
label var shadowpricedistrict_lrs "district weighted median sold unit value price if at least 10 values present"

foreach Y of varlist $districts {
quietly count if `Y'==1 & price_kg_tsh_hh!=. & (ag5a_01 !=.) 
		if `r(N)'>9 {
	_pctile price_kg_tsh_hh if `Y'==1 [pweight=y2_weight_2010], p(50)
	
	quietly replace shadowpriceclstr_source_district = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_ward==0 & shadowpriceclstr_source_ea==0
	quietly replace shadowpriceraw_source_district = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_ward==0 & shadowpriceraw_source_ea==0 & shadowpriceraw_source_self==0
	
	quietly replace shadowpricedistrict_lrs = r(r1) if `Y'==1 
	quietly replace shadowpricecluster_lrs = r(r1) if `Y'==1 & shadowpricecluster_lrs==.
	quietly replace shadowpriceraw_lrs = r(r1) if `Y'==1 & shadowpriceraw_lrs==.
	}
}


******** Region ********
gen shadowpriceregion_lrs=.
label var shadowpriceregion_lrs "Region weighted median sold unit value price if at least 10 values present"

foreach Y of varlist $regions {
quietly count if `Y'==1 & price_kg_tsh_hh!=. & (ag5a_01 !=.) 
		if `r(N)'>9 {
	_pctile price_kg_tsh_hh if `Y'==1 [pweight=y2_weight_2010], p(50)
	
	quietly replace shadowpriceclstr_source_region = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_district==0 & shadowpriceclstr_source_ward==0 & shadowpriceclstr_source_ea==0
	quietly replace shadowpriceraw_source_region = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_district==0 & shadowpriceraw_source_ward==0 & shadowpriceraw_source_ea==0 & shadowpriceraw_source_self==0
	
	quietly replace shadowpriceregion_lrs = r(r1) if `Y'==1 
	quietly replace shadowpricecluster_lrs = r(r1) if `Y'==1 & shadowpricecluster_lrs==.
	quietly replace shadowpriceraw_lrs = r(r1) if `Y'==1 & shadowpriceraw_lrs==.
	}
}



******** Zone ********
gen shadowpricezone_lrs=.
label var shadowpricezone_lrs "Zone weighted median sold unit value price if at least 10 values present"

foreach Y of varlist $zones {
quietly count if `Y'==1 & price_kg_tsh_hh!=. & (ag5a_01 !=.) 
		if `r(N)'>9 {
	_pctile price_kg_tsh_hh if `Y'==1 [pweight=y2_weight_2010], p(50)
	
	quietly replace shadowpriceclstr_source_zone = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_region==0 & shadowpriceclstr_source_district==0 & shadowpriceclstr_source_ward==0 & shadowpriceclstr_source_ea==0
	quietly replace shadowpriceraw_source_zone = 1 if r(r1)!=. & `Y'==1 & shadowpriceraw_source_region==0 & shadowpriceclstr_source_district==0 & shadowpriceraw_source_ward==0 & shadowpriceraw_source_ea==0 & shadowpriceraw_source_self==0
	
	quietly replace shadowpricezone_lrs = r(r1) if `Y'==1 
	quietly replace shadowpricecluster_lrs = r(r1) if `Y'==1 & shadowpricecluster_lrs==.
	quietly replace shadowpriceraw_lrs = r(r1) if `Y'==1 & shadowpriceraw_lrs==.
	}
}
	

******** National ********
gen shadowpricetz_lrs=.
label var shadowpricetz_lrs "National weighted median sold unit value price if at least 10 values present"

quietly count if price_kg_tsh_hh!=. & (ag5a_01 !=.)
	if `r(N)'>0 {
	_pctile price_kg_tsh_hh [pweight=y2_weight_2010], p(50)

	replace shadowpriceclstr_source_nat = 1 if r(r1)!=. & shadowpriceclstr_source_zone==0 & shadowpriceclstr_source_region==0 & shadowpriceclstr_source_district==0 & shadowpriceclstr_source_ward==0 & shadowpriceclstr_source_ea==0
	replace shadowpriceraw_source_nat = 1 if r(r1)!=. & shadowpriceraw_source_zone==0 & shadowpriceraw_source_region==0 & shadowpriceclstr_source_district==0 & shadowpriceraw_source_ward==0 & shadowpriceraw_source_ea==0 & shadowpriceraw_source_self==0
	
	replace shadowpricetz_lrs = r(r1)
	replace shadowpricecluster_lrs = r(r1) if shadowpricecluster_lrs==.
	replace shadowpriceraw_lrs = r(r1) if shadowpriceraw_lrs==.
	}



***** Convert series of dummy vars into one categorical variable *****
gen shadowpriceclstr_source=.
label var shadowpriceclstr_source "Categorical variable of what level clustered shadow price comes from"
replace shadowpriceclstr_source=1 if shadowpriceclstr_source_ea==1
replace shadowpriceclstr_source=2 if shadowpriceclstr_source_ward==1
replace shadowpriceclstr_source=3 if shadowpriceclstr_source_district==1
replace shadowpriceclstr_source=4 if shadowpriceclstr_source_region==1
replace shadowpriceclstr_source=5 if shadowpriceclstr_source_zone==1
replace shadowpriceclstr_source=6 if shadowpriceclstr_source_nat==1

gen shadowpriceraw_source=.
label var shadowpriceraw_source "Categorical variable of what level raw shadow price comes from"
replace shadowpriceraw_source=1 if shadowpriceraw_source_ea==1
replace shadowpriceraw_source=2 if shadowpriceraw_source_ward==1
replace shadowpriceraw_source=3 if shadowpriceraw_source_district==1
replace shadowpriceraw_source=4 if shadowpriceraw_source_region==1
replace shadowpriceraw_source=5 if shadowpriceraw_source_zone==1
replace shadowpriceraw_source=6 if shadowpriceraw_source_nat==1
replace shadowpriceraw_source=7 if shadowpriceraw_source_self==1

label define source1 1 "EA" 2 "Ward" 3 "District" 4 "Region" 5 "Zone" 6 "National" 7 "Self Reported"
label values shadowpriceclstr_source shadowpriceraw_source source1

*Only keep identifiers and new variables to merge back in
ren ea ea_id_hh //so it won't be confused with the ea_2010 variable which does not uniquely identify
keep hhid_p zaocode shadowpricecluster_lrs shadowpriceraw_lrs shadowpriceclstr_source shadowpriceraw_source harv_value_tsh ea_id_hh district

rename district district_true

**add _2010 to the end of each var
foreach x of varlist *{
rename `x' `x'_2010
}

//reversing these renames, because we need to merge on them
rename zaocode_2010 zaocode
rename hhid_p_2010 hhid_p

*Save to merge back into analysis dataset
save "$input\2010 data\Merged Data Shiny\W2_shadowprice.dta", replace
}



************
** WAVE 3 **
************
clear
use "$input\2012-13 data\Merged Data Shiny\w3_panel_merge"
tab ag5a_01_2012 if zaocode ==11 & wave3 ==1, missing //28 hh did not answer the question for maize, 582 sold, 1457 did not

//Step 1: get rid of all obs that are not maize
keep if zaocode ==11

//Step 2: generate HH-level price variable: value (TSH) / quantity (kg)
count if ag5a_01_2012 == 1 & ag5a_02_2012 ==.
count if ag5a_01_2012 == 1 & ag5a_03_2012 ==. 
//missing values do not look like a problem for the hh that did sell

** Calculate HH level price: value/quantity
gen price_kg_tsh_hh = ag5a_03_2012/ag5a_02_2012 
la var price_kg_tsh_hh "(ag5a_02-03) crop price per kilo received by household, TZ shillings"
sort ag_a01_1_2012 ag_a02_1_2012 ag_a04_1_2012
tab region ag5a_01

//inserting from .do file R:\Project\EPAR\Tanzania LSMS-ISA 2008-10 Master\Data and Do Files\Original Merged\HH\HH_PILLAR.14.04.09_V0.do
*Generate variable for zone
generate zone =.
recode zone .=1 if (region == 1 | region == 13)
recode zone .=2 if (region == 5 | region == 6 | region == 7)
recode zone .=3 if (region == 11 | region == 12 | region == 15)
recode zone .=4 if (region == 18 | region == 19 | region == 20)
recode zone .=5 if (region == 2 | region == 3 | region == 4 | region == 21)
recode zone .=6 if (region == 8 | region == 9 | region == 10)
recode zone .=7 if (region == 14 | region == 16 | region == 17)
recode zone .=8 if (region == 51 | region == 52 | region == 53 | region == 54 | region == 55)

label define zone1 1 "Central" 2 "Eastern" 3 "Southern Highlands" 4 "Lake" 5 "Northern" 6 "Southern" 7 "Western" 8 "Zanzibar"
label values zone zone1

ren ag_a01_1_2012 region

* ward and locality values change between 2008 and 2010. In 2008, two separate variables. In 2010, locality concatenated onto the end of ward.
* 35 unique ward values in 2008, 103 unique ward values in 2010 because "locality" digit was put at the end of the ward value in 2010
* to keep values consistent across years, disaggregate 2010 ward variable into its ward and locality components
* to separate digits in the 2010 ward variable, it needs to be a string variable
tostring ag_a03_1_2012, gen(ward_pp) 
* keep only the last digit to get the locality #
gen locality_p=substr(ward_pp, -1,.)
destring locality_p, gen(locality)
* keep only the first digit to get the ward # for wards under '10' 
gen ward_string=substr(ward_pp, 1, 1) if ag_a03_1_2012<100
* keep only the first 2 digits to get the ward # for wards over '10'
replace ward_string=substr(ward_pp, 1, 2) if ag_a03_1_2012>100 

//ward has either 1 or 2 digits now, make all 2 digits
gen ward_temp = "0" + ward_string if ag_a03_1_2012 <100
replace ward_string=ward_temp if ag_a03_1_2012<100

//district has 1 digit always, just make string
tostring ag_a02_1_2012, gen(district_string)

//region has 1 or 2 digits, make all 2 digit
tostring region, gen(region_string)
gen region_temp = "0" + region_string if region <10
replace region_string=region_temp if region<10

//EA has 1-3 digits, but we don't really care if these numbers are all the same length, so just tack it on the end and we will have a unique eaid
tostring ag_a04_1_2012, gen(ea_string)

* make unique variables at each geographic level
//district: region+district
gen district = region_string + district_string
la var district "unique district ID (created, region-district)"

//ward: region+district+ward
gen ward = region_string + district_string + ward_string
la var ward "unique ward ID (created, region-district-ward)"

//EA: reegion+district+ward+EA
gen ea = region_string + district_string + ward_string + ea_string
la var ea "unique EA ID (created, region-district-ward-ea)"

//check results
codebook district //124
codebook ward //593
codebook ea //1135


//////////////////////////////////////////////////////////////////////////////////////////////////////////////
********************************************* Set Survey Weights *********************************************
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

**Set Survey for 2012 Weights*** 
svyset clusterid [pweight=y3_weight_2012], strata(strataid) vce(linearized) singleunit(centered) || _n

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
************************************ 2012 Shadow Price Creation & Loops **************************************
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

*Create clustered sold price unit value medians for smallest geographic levels with at least 10 sold price values by crop
*Geographic levels: 1)Enumeration Area (EA) 2)Ward 3) District 4)Region 5)Zone 6)National
*Dummy variables for source of price countain the word 'source' on the variable name followed by geographic level or 'self' for self-reported

*Create dummy variables to keep track of which level the price came from, first self-reported, then geography loop.

gen shadowpriceraw_source_self = 0
replace shadowpriceraw_source_self = 1 if price_kg_tsh_hh!=. 
lab var shadowpriceraw_source_self "Shadow price raw created at self-reported level dummy"

* create nonsense variables for the sole purpose of running loops with these var names
gen clstr=0
gen raw=0
gen nat=0

* create series of geographic level dummies to keep track of which level the shadow price came from
* variables are dummies, therefore assign only zero values and no missing values (one dummy spans all seasons, therefore missing values not possible)
local values "clstr raw"
local geog "ea ward district region zone nat"
foreach x of varlist `values'{
	foreach y of varlist `geog'{
	gen shadowprice`x'_source_`y' = 0
	lab var shadowprice`x'_source_`y' "Shadow price `x' created at `y' level dummy"
	}
}

* drop nonsense variables as they are no longer needed
drop clstr raw nat

* make a variable for each value of each geographic level
tab zone, generate(x_zone)
tab region, generate(x_region)
tab district, gen(x_district)
tab ward, generate(x_ward)
tab ea, generate(x_ea)

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
******************************************** Create Globals **************************************************
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
*Create global lists of the geographical unit dummies in which median prices will be clustered
global zones x_zone*
global regions x_reg*
global districts x_dist*
global wards x_ward*
global eas x_ea*


///////////////// LRS Crops //////////////
*Generate general shadow price variables to be used for output value creation below.
*generate clustered prices based on median sold prices

gen shadowpricecluster_lrs=.
label var shadowpricecluster_lrs "Sold unit value price clustered median (smallest geo unit w/ >=10 price values)"
*generate shadow price variable equal to sold values when they are not missing. If MISSING, future commands will insert clustered median value (created below in loops) of lowest geographical unit with 10 or more observations"
gen shadowpriceraw_lrs=.
replace shadowpriceraw_lrs = price_kg_tsh_hh if price_kg_tsh_hh!=.
label var shadowpriceraw_lrs "Sold unit value price is reported HH value, if MISSING price is clustered median" 

******** EA ********
gen shadowpriceea_lrs=.
label var shadowpriceea_lrs "EA weighted median sold unit value price if at least 10 values present"

foreach Y of varlist $eas {
*foreach X of varlist $lrs {
quietly count if `Y'==1 & price_kg_tsh_hh!=. & (ag5a_01 !=.) 
	if `r(N)'>9 {
	_pctile price_kg_tsh_hh if `Y'==1 [pweight=y3_weight_2012], p(50)
	
	quietly replace shadowpriceclstr_source_ea = 1 if r(r1)!=. & `Y'==1 
	quietly replace shadowpriceraw_source_ea = 1 if r(r1)!=. & `Y'==1 & shadowpriceraw_source_self==0
	
	quietly replace shadowpriceea_lrs = r(r1) if `Y'==1 
	quietly replace shadowpricecluster_lrs = r(r1) if `Y'==1 
	quietly replace shadowpriceraw_lrs = r(r1) if `Y'==1 & shadowpriceraw_lrs==.
	}
}


******** Ward ********
gen shadowpriceward_lrs=.
label var shadowpriceward_lrs "Ward weighted median sold unit value price if at least 10 values present"

foreach Y of varlist $wards {
quietly count if `Y'==1 & price_kg_tsh_hh!=. & (ag5a_01 !=.) 
		if `r(N)'>9 {
	_pctile price_kg_tsh_hh if `Y'==1 [pweight=y3_weight_2012], p(50)
	
	quietly replace shadowpriceclstr_source_ward = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_ea==0
	quietly replace shadowpriceraw_source_ward = 1 if r(r1)!=. & `Y'==1 & shadowpriceraw_source_ea==0 & shadowpriceraw_source_self==0
	
	quietly replace shadowpriceward_lrs = r(r1) if `Y'==1 
	quietly replace shadowpricecluster_lrs = r(r1) if `Y'==1 & shadowpricecluster_lrs==.
	quietly replace shadowpriceraw_lrs = r(r1) if `Y'==1 & shadowpriceraw_lrs==.
	}
}

******** District ********
gen shadowpricedistrict_lrs=.
label var shadowpricedistrict_lrs "district weighted median sold unit value price if at least 10 values present"

foreach Y of varlist $districts {
quietly count if `Y'==1 & price_kg_tsh_hh!=. & (ag5a_01 !=.) 
		if `r(N)'>9 {
	_pctile price_kg_tsh_hh if `Y'==1 [pweight=y3_weight_2012], p(50)
	
	quietly replace shadowpriceclstr_source_district = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_ward==0 & shadowpriceclstr_source_ea==0
	quietly replace shadowpriceraw_source_district = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_ward==0 & shadowpriceraw_source_ea==0 & shadowpriceraw_source_self==0
	
	quietly replace shadowpricedistrict_lrs = r(r1) if `Y'==1 
	quietly replace shadowpricecluster_lrs = r(r1) if `Y'==1 & shadowpricecluster_lrs==.
	quietly replace shadowpriceraw_lrs = r(r1) if `Y'==1 & shadowpriceraw_lrs==.
	}
}


******** Region ********
gen shadowpriceregion_lrs=.
label var shadowpriceregion_lrs "Region weighted median sold unit value price if at least 10 values present"

foreach Y of varlist $regions {
quietly count if `Y'==1 & price_kg_tsh_hh!=. & (ag5a_01 !=.) 
		if `r(N)'>9 {
	_pctile price_kg_tsh_hh if `Y'==1 [pweight=y3_weight_2012], p(50)
	
	quietly replace shadowpriceclstr_source_region = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_district==0 & shadowpriceclstr_source_ward==0 & shadowpriceclstr_source_ea==0
	quietly replace shadowpriceraw_source_region = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_district==0 & shadowpriceraw_source_ward==0 & shadowpriceraw_source_ea==0 & shadowpriceraw_source_self==0
	
	quietly replace shadowpriceregion_lrs = r(r1) if `Y'==1 
	quietly replace shadowpricecluster_lrs = r(r1) if `Y'==1 & shadowpricecluster_lrs==.
	quietly replace shadowpriceraw_lrs = r(r1) if `Y'==1 & shadowpriceraw_lrs==.
	}
}



******** Zone ********
gen shadowpricezone_lrs=.
label var shadowpricezone_lrs "Zone weighted median sold unit value price if at least 10 values present"

foreach Y of varlist $zones {
quietly count if `Y'==1 & price_kg_tsh_hh!=. & (ag5a_01 !=.) 
		if `r(N)'>9 {
	_pctile price_kg_tsh_hh if `Y'==1 [pweight=y3_weight_2012], p(50)
	
	quietly replace shadowpriceclstr_source_zone = 1 if r(r1)!=. & `Y'==1 & shadowpriceclstr_source_region==0 & shadowpriceclstr_source_district==0 & shadowpriceclstr_source_ward==0 & shadowpriceclstr_source_ea==0
	quietly replace shadowpriceraw_source_zone = 1 if r(r1)!=. & `Y'==1 & shadowpriceraw_source_region==0 & shadowpriceclstr_source_district==0 & shadowpriceraw_source_ward==0 & shadowpriceraw_source_ea==0 & shadowpriceraw_source_self==0
	
	quietly replace shadowpricezone_lrs = r(r1) if `Y'==1 
	quietly replace shadowpricecluster_lrs = r(r1) if `Y'==1 & shadowpricecluster_lrs==.
	quietly replace shadowpriceraw_lrs = r(r1) if `Y'==1 & shadowpriceraw_lrs==.
	}
}
	

******** National ********
gen shadowpricetz_lrs=.
label var shadowpricetz_lrs "National weighted median sold unit value price if at least 10 values present"

quietly count if price_kg_tsh_hh!=. & (ag5a_01 !=.)
	if `r(N)'>0 {
	_pctile price_kg_tsh_hh [pweight=y3_weight_2012], p(50)

	replace shadowpriceclstr_source_nat = 1 if r(r1)!=. & shadowpriceclstr_source_zone==0 & shadowpriceclstr_source_region==0 & shadowpriceclstr_source_district==0 & shadowpriceclstr_source_ward==0 & shadowpriceclstr_source_ea==0
	replace shadowpriceraw_source_nat = 1 if r(r1)!=. & shadowpriceraw_source_zone==0 & shadowpriceraw_source_region==0 & shadowpriceclstr_source_district==0 & shadowpriceraw_source_ward==0 & shadowpriceraw_source_ea==0 & shadowpriceraw_source_self==0
	
	replace shadowpricetz_lrs = r(r1)
	replace shadowpricecluster_lrs = r(r1) if shadowpricecluster_lrs==.
	replace shadowpriceraw_lrs = r(r1) if shadowpriceraw_lrs==.
	}



***** Convert series of dummy vars into one categorical variable *****
gen shadowpriceclstr_source=.
label var shadowpriceclstr_source "Categorical variable of what level clustered shadow price comes from"
replace shadowpriceclstr_source=1 if shadowpriceclstr_source_ea==1
replace shadowpriceclstr_source=2 if shadowpriceclstr_source_ward==1
replace shadowpriceclstr_source=3 if shadowpriceclstr_source_district==1
replace shadowpriceclstr_source=4 if shadowpriceclstr_source_region==1
replace shadowpriceclstr_source=5 if shadowpriceclstr_source_zone==1
replace shadowpriceclstr_source=6 if shadowpriceclstr_source_nat==1

gen shadowpriceraw_source=.
label var shadowpriceraw_source "Categorical variable of what level raw shadow price comes from"
replace shadowpriceraw_source=1 if shadowpriceraw_source_ea==1
replace shadowpriceraw_source=2 if shadowpriceraw_source_ward==1
replace shadowpriceraw_source=3 if shadowpriceraw_source_district==1
replace shadowpriceraw_source=4 if shadowpriceraw_source_region==1
replace shadowpriceraw_source=5 if shadowpriceraw_source_zone==1
replace shadowpriceraw_source=6 if shadowpriceraw_source_nat==1
replace shadowpriceraw_source=7 if shadowpriceraw_source_self==1

label define source1 1 "EA" 2 "Ward" 3 "District" 4 "Region" 5 "Zone" 6 "National" 7 "Self Reported"
label values shadowpriceclstr_source shadowpriceraw_source source1

*Only keep identifiers and new variables to merge back in
keep hhid_p zaocode shadowpricecluster_lrs shadowpriceraw_lrs shadowpriceclstr_source shadowpriceraw_source harv_value_tsh

**add _2012 to the end of each var
foreach x of varlist *{
rename `x' `x'_2012
}

//reversing these renames, because we need to merge on them
rename zaocode_2012 zaocode
rename hhid_p_2012 hhid_p

*Save to merge back into analysis dataset
save "$input\2012-13 data\Merged Data Shiny\W3_shadowprice.dta", replace


