/*********************************************************************************************/
title1 'Dementia Algorithm - verify_dementia.sas (Jenner compatibility bundle)';

* Author: PF (adapted for standalone execution);
* Purpose: Run verification algorithm;
* Adapted from: programs/verify_dementia.sas (the %verify macro body below is unmodified)
* Input: Requires correct macro variables and processed claims;
* Output: Annual datasets with verified dementia dates;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

* The block below reproduces, for a standalone run, the small amount of setup
  that demv_wrap.sas normally performs (via %demv(...)) before %include-ing
  verify_dementia.sas: it derives id/year-window/censoring macro variables and
  builds the "claims" dataset (one row per bene_id/year/date with demdx/sympdx
  flags) that pull_dx_clms.sas would otherwise produce. userx=N (no drug data),
  vyear=1 (one-year verification window), matching the repo's own worked
  example in example/programs/input_program.sas;
%let id=bene_id;
%let minyear=2018;
%let maxyear=2019;
%let vyear=1;
%let userx=N;
%let vtime=365;

* Small fabricated synthetic post-pull_dx_clms claims sample: one diagnosis (demdx=1)
  followed by a second qualifying diagnosis within the verification window for
  bene_id 201 (should verify), and a single, unconfirmed diagnosis for bene_id 202
  (should NOT verify - no second dx, no qualifying death). All values invented for
  this bundle, not taken from repository data;
data claims;
	length bene_id 8;
	informat date death_date mmddyy10.;
	format date death_date mmddyy10.;
	input bene_id date demdx sympdx death_date;
	year=year(date);
	datalines;
201 03/01/2018 1 0 .
201 09/01/2018 1 0 .
202 05/15/2018 1 0 .
203 02/01/2019 1 0 06/01/2019
;
run;

proc sql noprint;
	select min(year) into :mindatayear from claims;
	select max(year) into :maxdatayear from claims;
quit;

%put First Year of Dementia Data: &mindatayear;
%put Last Year of Dementia Data: &maxdatayear;
%let censoryear=%eval(&maxdatayear.-&vyear.+1);
%put First Year with Censorship with &vyear.-Year Verification Window: &censoryear;

%if &minyear.<&censoryear.<=&maxyear. %then %let censor=1;
%put Censoring (1-Yes,0-No): &censor.;

data _null_;
	time=mdy(12,31,&maxdatayear.)-mdy(1,1,&mindatayear.)+1;
	call symput('time',time);
run;
%put &time.;

/* ---- Below this line is programs/verify_dementia.sas, unmodified ---- */

%macro verify;
data demv_long;
	set claims;
	by &id. year date;

	* Scenario 1: Two records of AD Diagnosis;

	%do yr=&mindatayear. %to &maxyear;
		retain scen_dx_dt&yr. scen_dx_vtime&yr. scen_dx_dx2dt&yr. scen_dx_dttype&yr. scen_dx_vtype&yr. scen_dx_vdt&yr. ;
		format scen_dx_dt&yr. scen_dx_vdt&yr. scen_dx_dx2dt&yr. mmddyy10. scen_dx_dttype&yr. scen_dx_vtype&yr. $4.;
		if (first.year and year=&yr.) or first.&id. then do;
			scen_dx_dt&yr.=.;
			scen_dx_dttype&yr.="";
			scen_dx_vtype&yr.="";
			scen_dx_vtime&yr.=.;
			scen_dx_dx2dt&yr.=.;
			scen_dx_vdt&yr.=.;
		end;
		if year>=&yr. then do;
			if demdx=1 then do;
				if scen_dx_dt&yr.=. and .<date-scen_dx_dx2dt&yr.<=&vtime. then do;
					scen_dx_dt&yr.=scen_dx_dx2dt&yr.;
					scen_dx_vdt&yr.=date;
					scen_dx_vtime&yr.=date-scen_dx_dt&yr.;
					scen_dx_dttype&yr.="1";
					scen_dx_vtype&yr.="1";
				end;
				else if scen_dx_dt&yr.=. and year(date)=&yr. then scen_dx_dx2dt&yr.=date;
			end;
		end;
	%end;

	* Death scenarios;
	%do yr=&mindatayear. %to &maxyear.;
	if (first.year and year=&yr.) or first.&id. then do;
		death_dx&yr.=.;
		death_dx_type&yr.="    ";
		death_dx_vtime&yr.=.;
	end;
	retain death_dx:;
	format death_dx&yr. death_date mmddyy10.;
	if year=&yr. then do;
		if death_dx&yr.=. and demdx and .<death_date-date<=365 then do;
			death_dx&yr.=date;
			death_dx_vtime&yr.=death_date-date;
			death_dx_type&yr.="1";
		end;
	end;
	%end;

	* Using death scenario as last resort if missing;
	if last.&id. then do;
		%do yr=&mindatayear. %to &maxyear.;
		if scen_dx_dt&yr.=. and death_dx&yr. ne . then do;
			scen_dx_dt&yr.=death_dx&yr.;
			scen_dx_vdt&yr.=death_date;
			scen_dx_vtime&yr.=death_dx_vtime&yr.;
			scen_dx_dttype&yr.=death_dx_type&yr.;
			scen_dx_vtype&yr.="   4";
		end;
		%end;
	end;

	%do yr=&mindatayear. %to &maxyear.;
	if .<scen_dx_vtime&yr.<0 then dropdx&yr.=1;

	label
	scen_dx_dt&yr.="ADRD incident date for scenario using only dx"
	scen_dx_vdt&yr.="Date of verification for scenario using only dx"
	scen_dx_vtime&yr.="Verification time for scenario using only dx"
	scen_dx_dttype&yr.="1-incident date is ADRD dx, 2-incident date is drug use, 3-incident date is dem symptom"
	scen_dx_vtype&yr.="1-verification date is ADRD dx, 2-verification date is drug use, 3-verification date is dem symptom, 4-verified by death"
	;
	%end;

	* Scenario Symp: dx +dx, dx + symp;
	array scen_dxsymp_dxdt_ [&time.] _temporary_;
	array scen_dxsymp_type_ [&time.] $4. _temporary_;

	if first.&id. then do;
		do i=1 to &time.;
			scen_dxsymp_dxdt_[i]=.;
			scen_dxsymp_type_[i]="";
		end;
	end;
	day=date-mdy(1,1,&mindatayear.)+1;
	start=max(1,date-mdy(1,1,&mindatayear.)-&vtime.+1);
	end=min(day,&time.);
	if (demdx or sympdx) and 1<=day<=&time. then do;
		scen_dxsymp_dxdt_[day]=date;
		if demdx then substr(scen_dxsymp_type_[day],1,1)="1";
		if sympdx then substr(scen_dxsymp_type_[day],3,1)="3";
	end;

	%do yr=&mindatayear. %to &maxyear.;

	*start is capped at start of year;
	startyr_day=mdy(1,1,&yr.)-mdy(1,1,&mindatayear.)+1;
	start=max(start,startyr_day);

	retain scen_dxsymp_dt&yr. scen_dxsymp_dxdt&yr. scen_dxsymp_dx2dt&yr. scen_dxsymp_vdt&yr. scen_dxsymp_vtime&yr. scen_dxsymp_dttype&yr.
		   scen_dxsymp_vtype&yr. scen_dxsymp_dx2type&yr.;
	format scen_dxsymp_dt&yr. scen_dxsymp_dxdt&yr. scen_dxsymp_dx2dt&yr. scen_dxsymp_vdt&yr. mmddyy10.
				scen_dxsymp_dttype&yr. scen_dxsymp_vtype&yr. scen_dxsymp_dx2type&yr. $4.;
	if (first.year and year=&yr.) or first.&id. then do;
		scen_dxsymp_dt&yr.=.;
		scen_dxsymp_vtime&yr.=.;
		scen_dxsymp_dxdt&yr.=.;
		scen_dxsymp_dx2dt&yr.=.;
		scen_dxsymp_dx2type&yr.="";
		scen_dxsymp_vdt&yr.=.;
		scen_dxsymp_dttype&yr.="";
		scen_dxsymp_vtype&yr.="";
	end;
	if &yr.<=year<=%eval(&yr.+1) then do;
		if scen_dxsymp_dt&yr.=. then do;
			do i=start to end;
				if (find(scen_dxsymp_type_[i],"1")) and scen_dxsymp_dxdt&yr.=. then scen_dxsymp_dxdt&yr.=scen_dxsymp_dxdt_[i];
				* getting second qualifying;
				if scen_dxsymp_dx2dt&yr.=. then do;
					if (scen_dxsymp_type_[i]="1" and scen_dxsymp_dxdt_[i]>scen_dxsymp_dxdt&yr.)
					or (find(scen_dxsymp_type_[i],"3")) then do;
						scen_dxsymp_dx2dt&yr.=scen_dxsymp_dxdt_[i];
						scen_dxsymp_dx2type&yr.=scen_dxsymp_type_[i];
					end;
				end;
			end;
			if scen_dxsymp_dxdt&yr. ne . and scen_dxsymp_dx2dt&yr. ne .
				and min(year(scen_dxsymp_dxdt&yr.),year(scen_dxsymp_dx2dt&yr.))=&yr. then do; * ensuring that minimum date is in year, otherwise, keep searching;
				if scen_dxsymp_dxdt&yr.<=scen_dxsymp_dx2dt&yr. then do;
					scen_dxsymp_dt&yr.=scen_dxsymp_dxdt&yr.;
					scen_dxsymp_vdt&yr.=scen_dxsymp_dx2dt&yr.;
					if scen_dxsymp_dxdt&yr.<scen_dxsymp_dx2dt&yr. then substr(scen_dxsymp_dttype&yr.,1,1)="1";
					if scen_dxsymp_dxdt&yr.=scen_dxsymp_dx2dt&yr. then scen_dxsymp_dttype&yr.="1 3";
					scen_dxsymp_vtype&yr.=scen_dxsymp_dx2type&yr.;
					scen_dxsymp_vtime&yr.=scen_dxsymp_dx2dt&yr.-scen_dxsymp_dxdt&yr.;
				end;
				if (scen_dxsymp_dx2dt&yr.<scen_dxsymp_dxdt&yr.) then do;
					scen_dxsymp_dt&yr.=scen_dxsymp_dx2dt&yr.;
					scen_dxsymp_vdt&yr.=scen_dxsymp_dxdt&yr.;
					scen_dxsymp_dttype&yr.=scen_dxsymp_dx2type&yr.;
					scen_dxsymp_vtype&yr.="1";
					scen_dxsymp_vtime&yr.=scen_dxsymp_dxdt&yr.-scen_dxsymp_dx2dt&yr.;
				end;
			end;
			else do;
				scen_dxsymp_dxdt&yr.=.;
				scen_dxsymp_dx2dt&yr.=.;
				scen_dxsymp_dx2type&yr.="";
			end;
		end;
	end;
	%end;

	* Death scenarios;
	%do yr=&mindatayear. %to &maxyear.;
	if (first.year and year=&yr.) or first.&id. then do;
		death_dxsymp&yr.=.;
		death_dxsymp_type&yr.="    ";
		death_dxsymp_v&yr.=.;
	end;
	retain death_dx:;
	format death_dxsymp&yr. death_date mmddyy10.;
	if year=&yr. then do;
		if death_dxsymp&yr.=. and (demdx) and .<death_date-date<=365 then do;
			death_dxsymp&yr.=date;
			death_dxsymp_vtime&yr.=death_date-date;
			if demdx then substr(death_dxsymp_type&yr.,1,1)="1";
		end;
	end;
	%end;

	* Using death scenario as last resort if missing;
	if last.&id. then do;
		%do yr=&mindatayear. %to &maxyear.;
		if scen_dxsymp_dt&yr.=. and death_dxsymp&yr. ne . then do;
			scen_dxsymp_dt&yr.=death_dxsymp&yr.;
			scen_dxsymp_vdt&yr.=death_date;
			scen_dxsymp_vtime&yr.=death_dxsymp_vtime&yr.;
			scen_dxsymp_dttype&yr.=death_dxsymp_type&yr.;
			scen_dxsymp_vtype&yr.="   4";
		end;
		%end;
	end;

	%do yr=&mindatayear. %to &maxyear.;
	if .<scen_dxsymp_vtime&yr.<0 then dropdxsymp&yr.=1;

	label
	scen_dxsymp_dt&yr.="ADRD incident date for scenario using dx and symptoms"
	scen_dxsymp_vdt&yr.="Date of verification for scenario using dx and symptoms"
	scen_dxsymp_vtime&yr.="Verification time for scenario using dx and symptoms"
	scen_dxsymp_dttype&yr.="1-incident date is ADRD dx, 2-incident date is drug use, 3-incident date is dem symptom"
	scen_dxsymp_vtype&yr.="1-verification date is ADRD dx, 2-verification date is drug use, 3-verification date is dem symptom, 4-verified by death"
	;
	%end;

	%if "&userx"="Y" %then %do;
	%end;
run;

/* Split out each into year, calculate first valid date, and keep last.&id. */
data
	%if &censor.=1 %then %do;
		%do yr=&minyear. %to  %eval(&censoryear.-1);
		 	dem&yr. (keep=&id. first_dx_dt first_dxsymp_dt
			 scen_dx_dt&yr. scen_dx_vdt&yr. scen_dx_vtime&yr. scen_dx_dttype&yr. scen_dx_vtype&yr. dropdx&yr.
			 scen_dxsymp_dt&yr. scen_dxsymp_vdt&yr. scen_dxsymp_vtime&yr. scen_dxsymp_dttype&yr. scen_dxsymp_vtype&yr. dropdxsymp&yr.
			)
		%end;
		%do yr=&censoryear. %to &maxyear.;
		 	dem&yr._censor (keep=&id. first_dx_dt first_dxsymp_dt
			 scen_dx_dt&yr. scen_dx_vdt&yr. scen_dx_vtime&yr. scen_dx_dttype&yr. scen_dx_vtype&yr. dropdx&yr.
			 scen_dxsymp_dt&yr. scen_dxsymp_vdt&yr. scen_dxsymp_vtime&yr. scen_dxsymp_dttype&yr. scen_dxsymp_vtype&yr. dropdxsymp&yr.
			)
		%end;
	 %end;
	%else %do;
		%do yr=&minyear. %to &maxyear.;
		 	dem&yr. (keep=&id. first_dx_dt first_dxsymp_dt
			 scen_dx_dt&yr. scen_dx_vdt&yr. scen_dx_vtime&yr. scen_dx_dttype&yr. scen_dx_vtype&yr. dropdx&yr.
			 scen_dxsymp_dt&yr. scen_dxsymp_vdt&yr. scen_dxsymp_vtime&yr. scen_dxsymp_dttype&yr. scen_dxsymp_vtype&yr. dropdxsymp&yr.
			)
		%end;
	%end;;
	format &id. first_dx_dt first_dxsymp_dt;
	set demv_long;
	by &id.;

	format first_dx_dt first_dxsymp_dt mmddyy10.;

	%if &censor.=1 %then %let lastyear=%eval(&censoryear.-1);
	%else %let lastyear=&maxyear.;
	%let firstyear=&mindatayear.;

	first_dx_dt=min(of scen_dx_dt&firstyear.-scen_dx_dt&lastyear.);
	first_dxsymp_dt=min(of scen_dxsymp_dt&firstyear.-scen_dxsymp_dt&lastyear.);
	if last.&id.;
run;

%mend;

%verify;

proc print data=dem2018; run;
%if &censor.=1 %then %do;
proc print data=dem2019_censor; run;
%end;
