/*********************************************************************************************/
title1 'Dementia Algorithm';

* Author: PF; 
* Purpose: 	Identify drugs for donepezil, galantamine, rivastigmine and memantine.
	See Techincal Documentation for definition;
* Input: Requires input drug claims dataset with following variables:
	- unique patient identifier
	- date
	- NDC or GNN
	;
* Output: Dementia drug claims;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

* List of GNNs - can add another drug to the end of the list if so desired;
%let gnn=donepezil galantamine memantine rivastigmine;
%let gnn_n=%sysfunc(countw(&gnn));
%put Number of GNN: &gnn_n;

* Read in NDC csv;
data ndc;
	infile "../csv_input/ndc2019.csv" dsd dlm="2c"x lrecl=32767 firstobs=2 missover;
	informat
		ndc best.
		gnn $21.
		donep best.
		galan best.
		meman best.
		rivas best.;
	format
		ndc best.
		gnn $21.
		donep best.
		galan best.
		meman best.
		rivas best.;
	input
		ndc 
		gnn 
		donep 
		galan 
		meman 
		rivas ;
run;

* Create macro code lists for NDC and GNN;
proc sql;
	select ndc
	into :ndc separated by " "
	from ndc;
quit;
%put List of NDCs as of 2019: &ndc;


* Pull related drugs, using GNN first if it exists and then only using NDC if GNN is not provided since NDC may not be updated with future years
of data;
%let rxn=%sysfunc(countw(&rxclaims," "));
%put Number of input RX datasets: &rxn;

%macro pullrx;
%do i=1 %to &rxn.;
%let inputrx=%scan(&rxclaims,&i.," ");

data rx&i.;
	set &inputrx.;

	rx_=0;
	%if "&hasgnn"="Y" %then %do;
		%do g=1 %to &gnn_n;
			if find(lowcase(gnn),scan("&gnn",&g))>0 then rx_=1;
		%end;
	%end;

	%else %if "&hasgnn"="N" %then %do; 
		if ndc in(&ndc) then rx_=1;
	%end;
	if rx_;

	year=year(date);
	
	keep &id. rx_ %if "&hasgnn"="Y" %then gnn; %else ndc; date year;
run;

proc sort data=rx&i. out=rx_s&i.; by &id. year date; run;
%end;

*stack;
data rxdt;
	set rx_s1 %if &rxn.>1 %then - rx_s&rxn.;;
	by &id. year date;

	* initialize rx and symp flags;
	if first.date then rx=0;

	retain rx;

	if rx_=1 then rx=1;

	if last.date;
	keep &id. date rx year;
run;
%mend;

%pullrx;





