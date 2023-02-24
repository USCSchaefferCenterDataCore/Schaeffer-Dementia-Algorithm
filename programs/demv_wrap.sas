/*********************************************************************************************/
TITLE1 'Dementia Algorithm';

* AUTHOR: Patricia Ferido;
* PURPOSE: Run all macro programs based on macro function inputs;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

***** Run all the macro programs based on macro function inputs;

%macro demv(projhome=,id=,minyear=,maxyear=,dxclaims=,vyear=2,outprefix=,userx=Y,rxclaims=,hasgnn=Y);

/* Macro variable checks*/
data _null_;
	if "&projhome"="" then do;
		put "ERROR: Fill out projhome";
		abort;
	end;
	if "&id"="" then do;
		put "ERROR: Fill out ID";
		abort;
	end;
	if "&minyear."="" then do;
		put "ERROR: Fill out minyear";
		abort;
	end;
	if "&maxyear."="" then do;
		put "ERROR: Fill out maxyear";
		abort;
	end;
	if "&dxclaims."="" then do;
		put "ERROR: Fill out dxclaims";
		abort;
	end;
	if "&vyear."="" then do;
		put "ERROR: Fill out vyear or remove the macro variable to use default (2)";
		abort;
	end;
	if &vyear. not in(1,2) then do;
		put "ERROR: vyear is an invalid value. Must be 1 or 2";
		abort;
	end;
	if "&outprefix."="" then do;
		put "ERROR: Fill out outprefix";
		abort;
	end;
	if "&userx" not in("Y","N") then do;
		put "ERROR: Userx is not a valid value, must be Y or N";
		abort;
	end;
	if "&userx"="Y" then do;
		if "&rxclaims."="" then do;
			put "ERROR: Fill out rxclaims";
			abort;
		end;
		if "&hasgnn." not in("Y","N") then do;
			put "ERROR: Hasgnn is not a valid vlue, must be Y or N";
			abort;
		end;
	end;
run;

* Set vtime to 365 days if vyear is 1 and 730 if vyear is 2;
%if &vyear.=1 %then %let vtime=365;
%else %if &vyear.=2 %then %let vtime=730;

/* Run programs to pull dx and drug claims */
%include "&projhome./programs/pull_dx_clms.sas";
%if "&userx"="Y" %then %include "&projhome./programs/pull_rx_clms.sas";;

/* Checks on input data sets */
* Merge together the drugs and claims data;
data claims;
	%if "&userx"="Y" %then merge dxdt (in=a) rxdt (in=b);;
	%if "&userx"="N" %then set dxdt;;
	by &id. year date;
	if demdx=. then demdx=0;
	if sympdx=. then sympdx=0;
	%if "&userx"="Y" %then if rx=. then rx=0;;
	year=year(date);
run;

* Get years of censored data;
proc freq data=claims noprint;
	table year / out=yr;
run;

proc sql noprint;
		select min(year) into :mindatayear
		from yr;
		
		select max(year) into :maxdatayear
		from yr;
quit;

%put First Year of Dementia Data: &mindatayear;
%put Last Year of Dementia Data: &maxdatayear;
%let censoryear=%eval(&maxdatayear.-&vyear.+1);
%put First Year with Censorship with &vyear.-Year Verification Window: &censoryear;

data _null_;
	* Checks;

	if &mindatayear.>&minyear. then do;
		put "ERROR: Provided data starts after specified minyear";
		abort;
	end;
	if &maxdatayear.<&maxyear. then do;
		put "ERROR: Provided data ends before specified maxyear";
		abort;
	end;
	if &censoryear.<=&minyear. then do;
		put "ERROR: All data will have censoring. Not enough data provided for &vyear.-Year Verification window";
		abort;
	end;

run;

%if &minyear.<&censoryear.<=&maxyear. %then %let censor=1;
%put Censoring (1-Yes,0-No): &censor.;

data _null_;
	time=mdy(12,31,&maxdatayear.)-mdy(1,1,&mindatayear.)+1;
	call symput('time',time);
run;
%put &time.;

%include "&projhome./programs/verify_dementia.sas";
%mend;


