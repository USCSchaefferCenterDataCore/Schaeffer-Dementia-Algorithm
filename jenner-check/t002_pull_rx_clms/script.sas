/*********************************************************************************************/
title1 'Dementia Algorithm - pull_rx_clms.sas (Jenner compatibility bundle)';

* Author: PF (adapted for standalone execution);
* Purpose: 	Identify drugs for donepezil, galantamine, rivastigmine and memantine.
	See Technical Documentation for definition;
* Adapted from: programs/pull_rx_clms.sas
* Input: Requires input drug claims dataset with following variables:
	- unique patient identifier
	- date
	- NDC or GNN
	;
* Output: Dementia drug claims;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

* Caller setup normally supplied by demv_wrap.sas / input_program.sas macro variables.
  hasgnn=Y exercises the generic-name matching branch of pull_rx_clms.sas;
%let id=bene_id;
%let rxclaims=inputrx;
%let hasgnn=Y;

* Small fabricated synthetic drug claims sample - bene_id, date, and a generic drug
  name (gnn), matching the schema pull_rx_clms.sas expects when hasgnn=Y.
  All values below are invented for this bundle;
data inputrx;
	length gnn $21;
	informat date mmddyy10.;
	format date mmddyy10.;
	input bene_id date gnn & $21.;
	datalines;
101 02/10/2018 DONEPEZIL HCL
102 05/03/2018 IBUPROFEN
103 07/22/2018 GALANTAMINE HBR
104 08/14/2019 MEMANTINE HCL
105 01/09/2019 ASPIRIN
;
run;

* List of GNNs - can add another drug to the end of the list if so desired;
%let gnn=donepezil galantamine memantine rivastigmine;
%let gnn_n=%sysfunc(countw(&gnn));
%put Number of GNN: &gnn_n;

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

proc print data=rxdt; run;
