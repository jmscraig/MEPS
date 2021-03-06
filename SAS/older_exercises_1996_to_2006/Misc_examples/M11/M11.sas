/********************************************************************\

PROGRAM:        C:\MEPS\PROG\EXAMPLE11.SAS

DESCRIPTION:    THIS EXAMPLE SHOWS THE PROCESS FOR MERGING PARENT'S
        INFORMATION TO CHILDREN'S RECORDS. IN THIS CASE, THE MOTHER'S
        AND FATHER'S EMPLOYMENT STATUS (EMPST31) IS MERGED TO
        CHILDREN, AGES 0-17. A NEW VARIABLE PAR_WORK IS CONSTURCTED TO
        SUMMARIZE IF THE CHILD HAS TWO WORKING PARENTS, ONE
        WORKING PARENT, OR NO WORKING PARENTS.

                                RUNS SURVEYFREQ THE NEW VARIABLE PAR_WORK.


INPUT FILE:     C:\MEPS\DATA\H105.SAS7BDAT (2006 FULL-YEAR DATA FILE)

\********************************************************************/

FOOTNOTE "PROGRAM: C:\MEPS\PROG\EXAMPLE11.SAS";

LIBNAME CDATA "C:\MEPS\DATA";

TITLE1 "AHRQ MEPS DATA USERS WORKSHOP -- SEPTEMBER 2009";

PROC FORMAT;
  VALUE KIDFMT 1="CHILD, AGE 0-17"
               0="NOT A CHILD";
  VALUE PAR_WORK
     1="1 BOTH PARENTS WORK"
     2="2 ONE PARENT WORK"
     3="3 NO WORKING PARENT"
     0="0 NOT A CHILD";
  VALUE EMPST31A
          -9,-8,-7,-1="NOT REPORTED"
           0=  "NO MOM OR DAD IN MEPS"
           1 = "1 EMPLOYED"
     2 = "2 JOB TO RETURN TO"
     3 = "3 JOB DURING ROUND"
     4 = "4 NOT EMPLOYED"
         ;
  VALUE MOMEMP
          -9,-8,-7,-1="NOT REPORTED"
           0=  "NO MOM IN MEPS"
           1 = "EMPLOYED"
     2,3,4 = "NOT EMPLOYED"
         ;
        VALUE DADEMP
          -9,-8,-7,-1="NOT REPORTED"
           0=  "NO DAD IN MEPS"
           1 = "1 EMPLOYED"
     2,3,4 = "NOT EMPLOYED"
   ;
RUN;

***************************************;
* READ 2006 CONSOLIDATED FULL YEAR FILE;
***************************************;
DATA ALL_FY06 ;
        SET CDATA.H105 (KEEP= DUPERSID DUID PID AGE31X MOPID31X
                                                          DAPID31X EMPST31 PERWT06F VARSTR VARPSU);
  WHERE PERWT06F GT 0;
RUN;

PROC PRINT DATA =ALL_FY06(OBS=50);
  VAR DUID DUPERSID AGE31X MOPID31X DAPID31X EMPST31;
        TITLE2 "SAMPLE PRINTOUT FROM DATASET ALL_FY06";
RUN;

**********************************************************;
* CREATE KIDS DATASET WITH LINKING IDS TO BOTH MOM AND DAD;
**********************************************************;
DATA KIDS (KEEP=DUPERSID MOMLINK DADLINK MOPID31X DAPID31X AGE31X);
        SET ALL_FY06(WHERE=(0 <= AGE31X <= 17));

        LENGTH MOMLINK DADLINK $8.;

  IF MOPID31X NE -1 THEN MOMLINK =PUT(DUID,Z5.)||PUT(MOPID31X, Z3.);
  IF DAPID31X NE -1 THEN DADLINK =PUT(DUID,Z5.)||PUT(DAPID31X, Z3.);

  LABEL MOMLINK= "DWELLING UNIT ID AND PID OF PERSON'S MOM-RD 3/1"
              DADLINK= "DWELLING UNIT ID AND PID OF PERSON'S DAD-RD 3/1";
        DROP EMPST31;
RUN;

PROC PRINT DATA =KIDS(OBS=50);
  TITLE2 "SAMPLE PRINTOUT FROM DATASET KIDS";
RUN;

*****************************************;
* CREATE "DADS" AND "MOMS" DATASETS -
* RENAME THE DUPERSID TO DADLINK AND MOMLINK
* FOR LINKING PURPOSES ONLY.
* IF THERE'S A MATCH ON THE KIDS
* FILE, THEN THE RECORD IS A "DAD" OR "MOM";
*****************************************;
DATA DADS;
        SET ALL_FY06 (KEEP=DUPERSID EMPST31 RENAME=(DUPERSID=DADLINK EMPST31=DAD_EMPST31));
RUN;
PROC SORT DATA =DADS; BY DADLINK; RUN;
PROC PRINT DATA=DADS (OBS=50);
  TITLE2 "DATASET DADS - ALL DUPERSIDS WITH DUPERSID RENAMED AS DADLINK";
RUN;

DATA MOMS;
        SET ALL_FY06(KEEP=DUPERSID EMPST31 RENAME=(DUPERSID=MOMLINK EMPST31=MOM_EMPST31));
RUN;
PROC SORT DATA =MOMS; BY MOMLINK; RUN;
PROC PRINT DATA=MOMS (OBS=50);
  TITLE2 "DATASET MOMS - ALL DUPERSIDS WITH DUPERSID RENAMED AS MOMLINK";
RUN;


***************************************;
** FIRST MERGE KIDS AND DADS BY DADLINK;
** THEN REPEAT MERGE FOR MOMLINK;
***************************************;
PROC SORT DATA =KIDS; BY DADLINK; RUN;
DATA KIDS2;
        MERGE KIDS (IN=A) DADS (IN=B);
  BY DADLINK;
  IF A;
  IF A AND NOT B THEN DAD_EMPST31=0;
RUN;

PROC SORT DATA=KIDS2; BY MOMLINK; RUN;
DATA KIDS_WPARENTS;
  MERGE KIDS2 (IN=A) MOMS (IN=B);
  BY MOMLINK;
  IF A;
  IF A AND NOT B THEN MOM_EMPST31=0;
  RUN;

PROC SORT DATA=KIDS_WPARENTS; BY DUPERSID; RUN;
PROC PRINT DATA=KIDS_WPARENTS (OBS=50);
  TITLE2 "DATASET KIDS WITH PARENTS INFORMATION";
  RUN;


***********************************;
* MERGE BACK TO ALL_FY06 TO PICK
* UP ENTIRE SAMPLE
***********************************;
DATA ALL2_FY06;
  MERGE KIDS_WPARENTS (IN=A)
        ALL_FY06 (IN=B);
  BY DUPERSID;
  IF A THEN DO;
    POP_KID=1;
    IF MOM_EMPST31=1 AND DAD_EMPST31=1 THEN PAR_WORK=1;
      ELSE IF MOM_EMPST31=1 OR DAD_EMPST31=1 THEN PAR_WORK=2;
      ELSE PAR_WORK=3;
     END;

    ELSE DO;
      POP_KID=0;
      DAD_EMPST31=-1;
      MOM_EMPST31=-1;
      PAR_WORK=0;
    END;

  LABEL="NUMBER OF WORKING PARENTS";
  RUN;


PROC PRINT DATA =ALL2_FY06 (OBS=50);
  VAR DUPERSID AGE31X MOMLINK DADLINK PAR_WORK MOM_EMPST31 DAD_EMPST31;
        TITLE2 "SAMPLE PRINTOUT FROM DATASET ALL2_FY06";
RUN;

PROC FREQ DATA=ALL2_FY06;
  TABLE POP_KID*PAR_WORK*MOM_EMPST31*DAD_EMPST31/LIST MISSING;
  FORMAT POP_KID KIDFMT. DAD_EMPST31 DADEMP. MOM_EMPST31 MOMEMP. PAR_WORK PAR_WORK.;
  RUN;

TITLE2 "FREQUENCY FOR PARENT'S EMPLOYMENT STATUS RD 3/1";
TITLE3 "WEIGHT = PERWT06F";
PROC SURVEYFREQ DATA =ALL2_FY06;
   STRATA VARSTR;
   CLUSTER VARPSU;
   WEIGHT PERWT06F;
   TABLES POP_KID*PAR_WORK/ ROW;
   FORMAT PAR_WORK PAR_WORK. POP_KID KIDFMT.;
RUN;
