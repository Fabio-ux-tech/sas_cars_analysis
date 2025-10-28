/* -----------------------------------------------------------
   SAS Project: Exploratory Analysis of Cars Dataset
   ----------------------------------------------------------- */

/* === STEP 0. SETUP ===================================================== */

/* 0.1 Create alias WORKLIB pointing to the WORK folder */
libname worklib "%sysfunc(pathname(work))";

/* Confirm lib successfully assigned */
libname;


/* === STEP 1. CREATE WORKING COPY ====================================== */

/* Copy SASHELP.CARS into WORKLIB so we can edit it freely */
data worklib.cars_raw;
  set sashelp.cars;
run;

/* Inspect structure */
proc contents data=worklib.cars_raw order=varnum;
  title "Cars Dataset Structure";
run;

/* Print first 10 rows */
proc print data=worklib.cars_raw (obs=10);
  title "Sample of Cars Dataset";
run;


/* === STEP 2. CLEANING & TRANSFORMATIONS =============================== */

/* Check missing values */
proc means data=worklib.cars_raw n nmiss;
  var MSRP Invoice EngineSize Cylinders Horsepower MPG_City MPG_Highway Weight Wheelbase Length;
  title "Missing Value Overview";
run;

/* Remove duplicates */
proc sort data=worklib.cars_raw out=worklib.cars_sorted nodupkey;
  by Make Model Type Origin DriveTrain MSRP;
run;

/* Create new variables and standardize text */
data worklib.cars_clean;
  set worklib.cars_sorted;
  PriceDiff      = MSRP - Invoice;
  PowerToWeight  = Horsepower / Weight;
  Make  = strip(Make);
  Model = strip(Model);
  Type  = propcase(strip(Type));
  /* Outlier flags */
  flag_price_outlier = (MSRP < 10000 or MSRP > 120000);
  flag_hp_outlier    = (Horsepower < 60 or Horsepower > 500);
run;


/* === STEP 3. DESCRIPTIVE STATISTICS =================================== */

/* Overall numeric stats */
proc means data=worklib.cars_clean mean median p25 p75 min max;
  var MSRP PriceDiff Horsepower MPG_City MPG_Highway PowerToWeight;
  title "Descriptive Statistics for Key Variables";
run;

/* Frequency counts */
proc freq data=worklib.cars_clean;
  tables Type Origin DriveTrain / nocum nopercent;
  title "Category Distributions";
run;

/* Segment averages using PROC SQL */
proc sql;
  create table worklib.segment_summary as
  select Type, Origin,
         count(*)          as n,
         mean(MSRP)        as avg_msrp format=comma10.0,
         mean(Horsepower)  as avg_hp   format=comma8.1,
         mean(MPG_City)    as avg_mpg_city,
         mean(MPG_Highway) as avg_mpg_hwy
  from worklib.cars_clean
  group by Type, Origin
  order by Type, Origin;
quit;

proc print data=worklib.segment_summary noobs;
  title "Segment Summary by Type and Origin";
run;


/* === STEP 4. VISUALIZATIONS =========================================== */

/* 4.1 MSRP distribution */
proc sgplot data=worklib.cars_clean;
  histogram MSRP;
  density MSRP;
  title "Distribution of MSRP (Price)";
run;

/* 4.2 Horsepower vs Price */
proc sgplot data=worklib.cars_clean;
  scatter x=Horsepower y=MSRP / group=Type transparency=0.2;
  reg x=Horsepower y=MSRP;
  title "Horsepower vs MSRP by Type";
run;

/* 4.3 Highway MPG by Type within DriveTrain */
proc sgpanel data=worklib.cars_clean;
  panelby DriveTrain / columns=3;
  vbox MPG_Highway / category=Type;
  title "Highway MPG by Type within DriveTrain";
run;


/* === STEP 5. RELATIONSHIPS & MINI MODEL =============================== */

/* Correlation matrix */
proc corr data=worklib.cars_clean nosimple plots=matrix(histogram);
  var MSRP Horsepower Weight PowerToWeight MPG_City MPG_Highway;
  title "Correlation Matrix of Key Metrics";
run;

/* Simple linear model */
proc reg data=worklib.cars_clean plots(unpack)=all;
  model MSRP = Horsepower MPG_Highway / vif;
  title "Simple Linear Regression: MSRP ~ Horsepower + MPG_Highway";
run;
quit;


/* === STEP 6. EXPORT OUTPUTS =========================================== */

/* Export summary to CSV (adjust your path) */
proc export data=worklib.segment_summary
  outfile="/home/u64378114/segment_summary.csv"
  dbms=csv replace;
run;


/* === STEP 7. CREATE POLISHED HTML REPORT ============================== */

ods html path="/home/u64378114"
         file="cars_report.html"
         style=HTMLBlue;

title "Executive Summary: Car Segments by Type & Origin";
proc print data=worklib.segment_summary label noobs;
run;

title "MSRP Distribution";
proc sgplot data=worklib.cars_clean;
  histogram MSRP; density MSRP;
run;

title "Horsepower vs MSRP by Type";
proc sgplot data=worklib.cars_clean;
  scatter x=Horsepower y=MSRP / group=Type;
  reg x=Horsepower y=MSRP;
run;

title "Highway MPG by Type within DriveTrain";
proc sgpanel data=worklib.cars_clean;
  panelby DriveTrain / columns=3;
  vbox MPG_Highway / category=Type;
run;

title "Correlation Overview";
proc corr data=worklib.cars_clean;
  var MSRP Horsepower Weight PowerToWeight MPG_City MPG_Highway;
run;

ods html close;


/* === END =============================================================== */
title;