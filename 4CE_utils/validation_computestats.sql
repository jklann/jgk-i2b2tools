-- Compute sensitivity/specificity/PPV/NPV for ICU|death compared to severity flag
-- Steps (continued in comments throughout the document, with SQL interspersed)

--  1) Use your version of Griffin's 4CE script (which you modified to submit 1.1 data) up to line 406 to build the #covid_cohort table. Make sure the code to pull death dates are acccurate for your site.
--      The original version is here: https://github.com/GriffinWeber/covid19i2b2/blob/master/4CE_Phase1.1_Files_mssql.sql
-- FROM THE SESSION WHERE YOU'VE RUN THE 4CE 1.1 SCRIPT (SO THE CODE CAN ACCESS THE TEMP TABLES):

--  2) Copy #covid_cohort to a permanent table. I used a table named covid_cohort_validation. This sql will do it:
        select * into covid_cohort_validation from #covid_cohort

-- 3) Copy the local codes used in your severity cohort definition to a new table called covid_cohort_severe_codes:
create table covid_cohort_severe_codes (cat varchar(50),concept_cd varchar(50))
GO
truncate table covid_cohort_severe_codes
GO
-- PaO2/PaCO2
insert into covid_cohort_severe_codes
select 'pao2',local_lab_code from #lab_map where loinc in ('2019-8','2703-7')
-- Severe medications
insert into covid_cohort_severe_codes
select med_class, local_med_code from #med_map where med_class in ('SIANES','SICARDIAC')
-- Acute respiratory distress syndrome (diagnosis)
insert into covid_cohort_severe_codes
select distinct 'ards', concept_cd 
    from observation_fact f
    inner join #covid_cohort c
        on f.patient_num = c.patient_num and f.start_date >= c.admission_date
    cross apply #config x
    where f.concept_cd in (code_prefix_icd10cm+'J80', code_prefix_icd9cm+'518.82')
-- Ventilator associated pneumonia (diagnosis)
insert into covid_cohort_severe_codes
select distinct 'pneumonia', concept_cd 
    from observation_fact f
    inner join #covid_cohort c
        on f.patient_num = c.patient_num and f.start_date >= c.admission_date
    cross apply #config x
    where f.concept_cd in (code_prefix_icd10cm+'J95.851', code_prefix_icd9cm+'997.31')
-- Insertion of endotracheal tube (procedure)
insert into covid_cohort_severe_codes
select distinct 'intubation', concept_cd 
    from observation_fact f
    inner join #covid_cohort c
        on f.patient_num = c.patient_num and f.start_date >= c.admission_date
    cross apply #config x
    where f.concept_cd in (code_prefix_icd10pcs+'0BH17EZ', code_prefix_icd9proc+'96.04')
-- Invasive mechanical ventilation (procedure)
insert into covid_cohort_severe_codes
select distinct 'vent', concept_cd 
    from observation_fact f
    inner join #covid_cohort c
        on f.patient_num = c.patient_num and f.start_date >= c.admission_date
    cross apply #config x
where f.concept_cd like code_prefix_icd10pcs+'5A09[345]%'
or f.concept_cd like code_prefix_icd9proc+'96.7[012]'
GO

-- THE FOLLOWING STEPS CAN BE RUN IN ANY SESSION (THEY DO NOT RELY ON THE 4CE SCRIPTS' TEMP TABLES):

--  4) Create a table holding your patient's ICU status. I created a simple one called covid_cohort_icu with patient_num, icu_admit_date, icu_discharge_date for all ICU stays.
--    Mine is restricted to the covid cohort, but this is not a requirement for this script - the join will take care of it.

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
        inner join covid_cohort_validation c on c.patient_num=i.patient_num and c.admission_date>=i.icu_admit_date
        group by i.patient_num
		) s on c.patient_num = s.patient_num
GO

-- 6) Compute counts
--    Put sensitivity & specificity & ppv & npv into the spreadsheet at https://docs.google.com/spreadsheets/d/1Qd3XNz1hjRy9SRt0K7guIAUDFRAmA7A2TC0vd3nsU9g/edit?usp=sharing
--    You are also encourage to include the 2x2 table if that doesn't violate your local policies (because the counts are not obfuscated)
select (test_outcome+0.0)/(test_outcome+outcome_only) sensitivity, (neither+0.0)/(test_only+neither) specificity, (test_outcome+0.0)/(test_outcome+test_only) ppv, (neither+0.0)/(neither+outcome_only) npv, z.* from
(select sum(icudeath*severe) test_outcome, sum(icudeath)-sum(icudeath*severe) outcome_only, sum(severe)-sum(icudeath*severe) test_only, sum(case when icudeath=0 and severe=0 then 1 else 0 end) neither from
(select *, case when icu=1 or death=1 then 1 else 0 end icudeath from 
(select patient_num, icu, case when death_date is not null then 1 else 0 end death, severe from covid_cohort_validation v) x ) y) z
 
-- 7) Compute prevalence of the severe measure categories and the outcomes (icu and death) among those flagged severe
-- Please also copy these percentages into the above spreadsheet
select f.patient_num, min(start_date) start_date,cat into #severe_by_cat from observation_fact f 
   inner join covid_cohort_validation c on f.patient_num = c.patient_num and f.start_date >= c.admission_date
   inner join covid_cohort_severe_codes s on s.concept_cd=f.concept_cd
   group by f.patient_num,cat
GO
-- Prevalence of outcomes 
select cat, prevalence from 
(select sum(0.0+icu*severe)/sum(severe) icu,sum(0.0+severe*death)/sum(severe) dead from 
(select patient_num, icu, case when death_date is not null then 1 else 0 end death, severe from covid_cohort_validation v) x ) y
 UNPIVOT (prevalence for cat in (icu,dead)) u
-- Prevalence of codes
UNION ALL
 select cat, (0.0+cnt)/tot prevalence from (select cat, count(*) cnt from #severe_by_cat group by cat) x 
   full outer join 
   (select count(*) tot from #severe_by_cat) z on 2=2
 GO
 
-- 8) NO NEED TO DO THIS PRESENTLY. Optional: export data for R code 
-- Export this as labels.csv
select patient_num, admission_date hospitalization_date, case when death_date is not null or icu=1 then 'Y' else 'N' end label  from covid_cohort_validation
-- Export this as facts.csv
select f.patient_num, f.concept_cd phenx,start_date,cat  from observation_fact f 
   inner join covid_cohort_validation c on f.patient_num = c.patient_num and f.start_date >= c.admission_date
   inner join covid_cohort_severe_codes s on s.concept_cd=f.concept_cd


