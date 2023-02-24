/*********************************************************************************************/
title1 'Dementia Algorithm';

* Author: PF; 
* Purpose: 	Identify dementia and dementia symptom claims. See Techincal Documentation for definition;
* Input: Requires input claims dataset with following variables:
	- unique patient identifier
	- icd_dx[i]
	- date
	- death_dt
	;
* Output: Dementia dx claims;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;
* Bring in CSV with codes;
data icd;
	infile "../csv_input/icdcodes.csv" dsd dlm="2c"x lrecl=32767 missover firstobs=2;
	informat
		cond $4.
		type $8.
		code $7.
		desc $70.;
	format
		cond $4.
		type $8.
		code $7.
		desc $70.;
	input
		cond 
		type
		code 
		desc ;
run;

* Create macro variable lists to flag;
proc sql;
	
	* Dementia dx ICD-9;
	select code
	into :icd9dem separated by '","'
	from icd
	where type="ICD9DX" and cond="dem";

	* Dementia dx ICD-10;
	select code
	into :icd10dem separated by '","'
	from icd
	where type="ICD10DX" and cond="dem";

	* Symptom dx ICD-9;
	select code
	into :icd9symp separated by '","'
	from icd
	where type="ICD9DX" and cond="symp";

	* Symptom dx ICD-10;
	select code
	into :icd10symp separated by '","'
	from icd
	where type="ICD10DX" and cond="symp";

quit;

%put "&icd9dem";
%put "&icd10dem";
%put "&icd9symp";
%put "&icd10symp";

* Flag dementia claims in input claims dataset and make it date level;
%let dxn=%sysfunc(countw(&dxclaims," "));
%put Number of Input Claims data sets: &dxn;

%macro pulldx;
%do i=1 %to &dxn.;
%let inputdx=%scan(&dxclaims,&i.," ");
data dx&i.;
	set &dxclaims.;

	array icd [*] icd_dx:;
	dem=0;
	symp=0;
	do i=1 to dim(icd) while(dem=0 or symp=0);
		if icd[i] in("&icd9dem","&icd10dem") then dem=1;
		if icd[i] in("&icd9symp","&icd10symp") then symp=1;
	end;
	year=year(date);
	if dem or symp;
run;

proc sort data=dx&i. out=dx_s&i.; by &id. year date; run;
%end;

*stack;
data dxdt;
	set dx_s1 %if &dxn.>1 %then -dx_s&dxn.;;
	by &id. year date;

	* initialize dx and symp flags;
	if first.date then do;
		demdx=0;
		sympdx=0;
	end;
	retain demdx sympdx;

	if dem=1 then demdx=1;
	if symp=1 then sympdx=1;

	if last.date;
	keep &id. year date demdx sympdx death_date;
run;
%mend;

%pulldx;















