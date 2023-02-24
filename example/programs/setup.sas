/*********************************************************************************************/
title1 'Dementia Algorithm';

* Author: PF; 
* Purpose: Set up my input claims data for the package;
* Input: Synthetic claims data;
* Output: data.claims;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

libname data "../data";
	
* Setting up my claims data;
data data.inputclaims;
	set data.claims2014-data.claims2017;
	array icd [*] $ icd_dx1-icd_dx10;
	array icd9 [*] icd9dx1-icd9dx10;
	array icd10 [*] icd10dx1-icd10dx10;
	
	do i=1 to dim(icd);
		if icd9[i] ne "" then icd[i]=compress(icd9[i],".");
		if icd10[i] ne "" then icd[i]=compress(icd10[i],".");
	end;
	
	if icd_dx1="331" then icd_dx1="3310";
	
	rename claim_dt=date;
	
	* Adding synthetic birth dates;
	if bene_id=3 then death_date=mdy(8,1,2014);
	if bene_id=0 then death_date=mdy(4,1,2017);
	if bene_id=1 then death_date=mdy(2,1,2016);
	if bene_id=2 then death_date=.;
	format death_date mmddyy10.;
	
	drop icd9: icd10: claim_type i;
run;

proc print data=data.inputclaims; run;
	
	