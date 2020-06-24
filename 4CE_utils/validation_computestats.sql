-- Compute sensitivity/specificity/PPV/NPV for ICU|death compared to severity flag
-- Instructions:
--  1) Use your version of Griffin's 4CE script (which you modified to submit 1.1 data) up to line 406 to build the #covid_cohort table. Make sure the code to pull death dates are acccurate for your site.
--      The original version is here: https://github.com/GriffinWeber/covid19i2b2/blob/master/4CE_Phase1.1_Files_mssql.sql
--  2) Copy #covid_cohort to a permanent table. I used a table named covid_cohort_validation. This sql will do it:
--       select * into covid_cohort_validation from #covid_cohort
--  3) Create a table holding your patient's ICU status. I created a simple one called covid_cohort_icu with patient_num, icu_admit_date, icu_discharge_date for all ICU stays.
--    It is restricted to the covid cohort, but this is not a requirement for this script - the join will take care of it.

--  4) Add an ICU column to the table and get ICU status from the ICU table in step 3.
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

-- 5) Compute counts
--    Put sensitivity & specificity & ppv & npv into the spreadsheet at 
--    You are also encourage to include the 2x2 table if that doesn't violate your local policies (because the counts are not obfuscated)
select (test_outcome+0.0)/(test_outcome+outcome_only) sensitivity, (neither+0.0)/(test_only+neither) specificity, (test_outcome+0.0)/(test_outcome+test_only) ppv, (neither+0.0)/(neither+outcome_only) npv, z.* from
(select sum(icudeath*severe) test_outcome, sum(icudeath)-sum(icudeath*severe) outcome_only, sum(severe)-sum(icudeath*severe) test_only, sum(case when icudeath=0 and severe=0 then 1 else 0 end) neither from
(select *, case when icu=1 or death=1 then 1 else 0 end icudeath from 
(select patient_num, icu, case when death_date is not null then 1 else 0 end death, severe from covid_cohort_validation v) x ) y) z
 