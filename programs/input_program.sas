/*********************************************************************************************/
title1 'Dementia Algorithm';

* Author: PF; 
* Purpose: Houses all the input macro variables and runs all programs related to the dementia algorithm;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

************** Set up libnames - optional;
* libname;

/********************************************************************************************
Macro Variables - Information needed for macro below
* PROJHOME: project filepath to the folder
* ID: name of the unique patient identifier
* MINYEAR: start year of data
* MAXYEAR: end year of data (should be last two years to allow for )
* DXCLAIMS: names of the diagnosis claims data to process. If multiple, separate by a space
* VYR: 1/2, 1- Verify dx in 1 year, 2 - Verify dx in 2 years (default)
* OUTPREFIX: desired prefix for annual output data sets, output will be &outprefix.[yr] and &outprefix.[yr]_censor
		if not enough time for full verification
* USERX: Y/N, Y - use drug data (default), N - don't use drug data 
	* If Y, then define the following variables:
		* RXCLAIMS: name of drug claims data to process. If multiple, separate by a space
		* HASGNN - Y/N, Y - Data has GNN, don't use NDC (default), N - Data does not have GNN, use NDC
********************************************************************************************/

****** Wrapper macro;
%include "demv_wrap.sas";

****** Macro Function - please fill in with above information;
%demv(projhome=,
	  id=,
	  minyear=,
	  maxyear=,
	  dxclaims=,
	  vyear=,
	  outprefix=,
	  userx=,
	  rxclaims=,
	  hasgnn=);

***** Example;
/*%demv(projhome=/research/dementia/,
	  id=bene_id,
	  minyear=2017,
	  maxyear=2019,
	  dxclaims=dem.claims2017 dem.claims2018 dem.claims2019 dem.claims2020 dem.claims2021,
	  vyr=2,
	  outprefix=dem.demv,
	  userx=Y,
	  rxclaims=dem.rxclaims2017 dem.rxclaims2018 dem.rxclaims2019 dem.rxclaims2020 dem.rxclaims2021,
	  hasgnn=Y);*/





