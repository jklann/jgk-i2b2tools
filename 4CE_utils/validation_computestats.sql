-- Compute sensitivity/specificity/PPV/NPV for ICU|death compared to severity flag
-- Steps (continued in comments throughout the document, with SQL interspersed)

--  1) Use your version of Griffin's 4CE script (which you modified to submit 1.1 data) up to line 406 to build the #covid_cohort table. Make sure the code to pull death dates are acccurate for your site.
--      The original version is here: https://github.com/GriffinWeber/covid19i2b2/blob/master/4CE_Phase1.1_Files_mssql.sql
-- FROM THE SESSION WHERE YOU'VE RUN THE 4CE 1.1 SCRIPT (SO THE CODE CAN ACCESS THE TEMP TABLES):

--  2) Copy #covid_cohort to a permanent table. I used a table named covid_cohort_validation. This sql will do it:
        select * into covid_cohort_validation from #covid_cohort

-- 3) Copy the local codes used in your severity cohort definition to a new table called covid_cohort_severe_codes:
create table covid_cohort_severe_codes (c_domain varchar(50),cat varchar(50),concept_cd varchar(50))
GO
truncate table covid_cohort_severe_codes
GO
-- PaO2/PaCO2
insert into covid_cohort_severe_codes
select distinct 'lab','pao2',local_lab_code from #lab_map where loinc in ('2019-8','2703-7')
-- Severe medications
insert into covid_cohort_severe_codes
select distinct 'rx', med_class, local_med_code from #med_map where med_class in ('SIANES','SICARDIAC')
-- Acute respiratory distress syndrome (diagnosis)
insert into covid_cohort_severe_codes
select distinct 'dxpx','ards', concept_cd 
    from observation_fact f
    inner join #covid_cohort c
        on f.patient_num = c.patient_num and f.start_date >= c.admission_date
    cross apply #config x
    where f.concept_cd in (code_prefix_icd10cm+'J80', code_prefix_icd9cm+'518.82')
-- Ventilator associated pneumonia (diagnosis)
insert into covid_cohort_severe_codes
select distinct 'dxpx','pneumonia', concept_cd 
    from observation_fact f
    inner join #covid_cohort c
        on f.patient_num = c.patient_num and f.start_date >= c.admission_date
    cross apply #config x
    where f.concept_cd in (code_prefix_icd10cm+'J95.851', code_prefix_icd9cm+'997.31')
-- Insertion of endotracheal tube (procedure)
insert into covid_cohort_severe_codes
select distinct 'dxpx','intubation', concept_cd 
    from observation_fact f
    inner join #covid_cohort c
        on f.patient_num = c.patient_num and f.start_date >= c.admission_date
    cross apply #config x
    where f.concept_cd in (code_prefix_icd10pcs+'0BH17EZ', code_prefix_icd9proc+'96.04')
-- Invasive mechanical ventilation (procedure)
insert into covid_cohort_severe_codes
select distinct 'dxpx','vent', concept_cd 
    from observation_fact f
    inner join #covid_cohort c
        on f.patient_num = c.patient_num and f.start_date >= c.admission_date
    cross apply #config x
where f.concept_cd like code_prefix_icd10pcs+'5A09[345]%'
or f.concept_cd like code_prefix_icd9proc+'96.7[012]'
GO

-- THE FOLLOWING STEPS CAN BE RUN IN ANY SESSION (THEY DO NOT RELY ON THE 4CE SCRIPTS' TEMP TABLES):

--  4) Create a table holding your patient's ICU status. I created a simple one called covid_cohort_icu with patient_num, icu_admit_date, icu_discharge_date for all ICU stays.
--    Mine is restricted to the covid cohort, but this is not a requirement for this script - the join in the next step will take care of it.
--    The two examples below use a derived fact or CPT codes, respectively.
--    *** MODIFY THIS FOR YOUR SITE! ***

 -- This version works with the ACT Critical Care derived fact for ICU stays
 select c.patient_num, start_date as icu_admit_date, end_date as icu_discharge_date into covid_cohort_icu 
  from covid_cohort_validation c inner join observation_fact f  
   on c.patient_num=f.patient_num and f.start_date>=c.admission_date
   where concept_cd = 'UMLS:C1547136'

 -- This version uses CPT codes 99291 and 99292, drawing local mappings from the act_covid ontology.
 -- Use the CPT approach if your site does not have more accurate data from the EHR.
 select c.patient_num, start_date as icu_admit_date, end_date as icu_discharge_date into covid_cohort_icu
  from covid_cohort_validation c inner join observation_fact f  
   on c.patient_num=f.patient_num and f.start_date>=c.admission_date
   where concept_cd in 
     (select c_basecode from act_covid where C_FULLNAME like '%\CPT4_99291\%' or c_fullname like '%\CPT4_99292\%')

--  5) Add an ICU column to the table and get ICU status from the ICU table in step 3.
--    If your ICU table is different than mine, you will need to alter the logic in the inner join (see below).
alter table covid_cohort_validation add icu int,icu_date date
GO
update c
	set c.icu = 0
	from covid_cohort_validation c where c.icu is null
GO
update c
	set c.icu = 1, c.icu_date = s.icu_date
	from covid_cohort_validation c
		inner join (
	-- Alter this logic as needed to get first ICU admission after COVID hospitalization
    select i.patient_num, min(icu_admit_date) icu_date from covid_cohort_icu i
        inner join covid_cohort_validation c on c.patient_num=i.patient_num and i.icu_admit_date>=c.admission_date -- bugfix 7/29/20
        group by i.patient_num
		) s on c.patient_num = s.patient_num
GO 

-- 6) Compute statistics (now includes ICU OR DEATH as well as ICU, DEATH separately)
--    Put sensitivity & specificity & ppv & npv into the spreadsheet at https://docs.google.com/spreadsheets/d/1Qd3XNz1hjRy9SRt0K7guIAUDFRAmA7A2TC0vd3nsU9g/edit?usp=sharing
--    You are also encourage to include the 2x2 table if that doesn't violate your local policies (because the counts are not obfuscated)
--- ICU OR DEATH
select 'ICU|DEATH' as outcome, (test_outcome+0.0)/(test_outcome+outcome_only) sensitivity, (neither+0.0)/(test_only+neither) specificity, (test_outcome+0.0)/(test_outcome+test_only) ppv, (neither+0.0)/(neither+outcome_only) npv, z.* from
(select sum(icudeath*severe) test_outcome, sum(icudeath)-sum(icudeath*severe) outcome_only, sum(severe)-sum(icudeath*severe) test_only, sum(case when icudeath=0 and severe=0 then 1 else 0 end) neither from
(select *, case when icu=1 or death=1 then 1 else 0 end icudeath from 
(select patient_num, icu, case when death_date is not null then 1 else 0 end death, severe from covid_cohort_validation v) x ) y) z
UNION ALL
-- ICU
select 'ICU' as outcome, (test_outcome+0.0)/(test_outcome+outcome_only) sensitivity, (neither+0.0)/(test_only+neither) specificity, (test_outcome+0.0)/(test_outcome+test_only) ppv, (neither+0.0)/(neither+outcome_only) npv, z.* from
(select sum(icudeath*severe) test_outcome, sum(icudeath)-sum(icudeath*severe) outcome_only, sum(severe)-sum(icudeath*severe) test_only, sum(case when icudeath=0 and severe=0 then 1 else 0 end) neither from
(select *, case when icu=1 then 1 else 0 end icudeath from 
(select patient_num, icu, case when death_date is not null then 1 else 0 end death, severe from covid_cohort_validation v) x ) y) z
UNION ALL
 -- Death
select 'DEATH' as outcome, (test_outcome+0.0)/(test_outcome+outcome_only) sensitivity, (neither+0.0)/(test_only+neither) specificity, (test_outcome+0.0)/(test_outcome+test_only) ppv, (neither+0.0)/(neither+outcome_only) npv, z.* from
(select sum(icudeath*severe) test_outcome, sum(icudeath)-sum(icudeath*severe) outcome_only, sum(severe)-sum(icudeath*severe) test_only, sum(case when icudeath=0 and severe=0 then 1 else 0 end) neither from
(select *, case when death=1 then 1 else 0 end icudeath from 
(select patient_num, icu, case when death_date is not null then 1 else 0 end death, severe from covid_cohort_validation v) x ) y) z

-- 7) Compute prevalence of the severe measure categories and the outcomes (icu and death) among those flagged severe 
-- 7/21/20 - now also computes overlap (i.e. Venn diagram)
-- Please also copy these percentages into the above spreadsheet
select f.patient_num, min(start_date) start_date,cat,c_domain into #severe_by_cat from observation_fact f 
   inner join covid_cohort_validation c on f.patient_num = c.patient_num and f.start_date >= c.admission_date
   inner join covid_cohort_severe_codes s on s.concept_cd=f.concept_cd
   group by f.patient_num,cat,c_domain
GO
-- Prevalence of outcomes 
select cat, prevalence from 
(select sum(0.0+icu*severe)/sum(severe) icu,sum(0.0+severe*death)/sum(severe) dead from 
(select patient_num, icu, case when death_date is not null then 1 else 0 end death, severe from covid_cohort_validation v) x ) y
 UNPIVOT (prevalence for cat in (icu,dead)) u
-- Prevalence of codes
UNION ALL
 select cat, (0.0+cnt)/tot prevalence from (select cat, count(distinct patient_num) cnt from #severe_by_cat group by cat) x 
   full outer join 
   (select count(distinct patient_num) tot from #severe_by_cat) z on 2=2
 GO
  
-- 7.5) Optional: Submit counts for Venn diagram 
--   *** ONLY SUBMIT THESE COUNTS IF YOUR IRB ALLOWS YOU TO SUBMIT UNBLURRED COUNTS FOR AGGREGATE QUERIES. **
-- Note that we do need the unblurred counts to accurately calculate the Venn diagram. It is a bit tricky - (x,y) could be (x,y,z) or (x,y,~z)
-- If you cannot submit unblurred counts I can help you calculate the Venn diagram numbers and then you can submit these as a percent of severe patients.
(select c_domain, count(distinct patient_num) cnt from #severe_by_cat group by c_domain) 
UNION ALL 
(select c1.c_domain+','+c2.c_domain label,count(distinct c1.patient_num) cnt from #severe_by_cat c1 inner join #severe_by_cat c2 on c1.patient_num=c2.patient_num
 where c1.c_domain<c2.c_domain group by c1.c_domain, c2.c_domain) 
UNION ALL
(select distinct 'ALL' label, count(distinct c1.patient_num) cnt from #severe_by_cat c1 inner join #severe_by_cat c2 
 on c1.patient_num=c2.patient_num inner join #severe_by_cat c3 on c1.patient_num=c3.patient_num and c2.patient_num=c3.patient_num
 where c1.c_domain!=c2.c_domain and c1.c_domain!=c3.c_domain and c2.c_domain!=c3.c_domain group by c1.c_domain, c2.c_domain, c3.c_domain) 
UNION ALL
(select distinct 'ANY' label, count(distinct patient_num) cnt from #severe_by_cat)
   
-- 8) Optional: export data for R code (also in the GitHub)
-- Export this as labels.csv
select patient_num, admission_date hospitalization_date, case when death_date is not null or icu=1 then 'Y' else 'N' end label  from covid_cohort_validation
-- Export this as facts.csv
select f.patient_num, cat phenx,start_date,f.concept_cd  from observation_fact f 
   inner join covid_cohort_validation c on f.patient_num = c.patient_num and f.start_date >= c.admission_date
   inner join covid_cohort_severe_codes s on s.concept_cd=f.concept_cd
