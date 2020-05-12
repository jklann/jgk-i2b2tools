-- Populate the #code_map table with race, ethnicity, and gender codes found in ncats_demographics. 
-- For ACT sites that want to run the 4CE script: https://github.com/GriffinWeber/covid19i2b2/blob/master/4CE_Phase1.1_Files_mssql.sql
-- Adapted from code by Aaron Abend in the i2b2-to-PCORnet transform: https://github.com/ARCH-commons/i2p-transform
-- Adaptation by Jeff Klann, PhD 05-2020. Can be found at https://github.com/jklann/jgk-i2b2tools

-- 1. Create and populate the #code_map table, but do not include race, ethnicity, and gender codes
-- 2. Run this script to add them to the table
-- 3. If your ACT demographics table is not called ncats_demographics, change the table references in the code below.

create table #act_codelist (codetype varchar(20), codename varchar(50),code varchar(50))
go
truncate table #act_codelist
GO
----------------------------------------------------------------------------------------------------------------------------------------
-- Prep-to-transform code
----------------------------------------------------------------------------------------------------------------------------------------

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[parsecode]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[parsecode]
GO

create procedure parsecode (@codetype varchar(20), @codename varchar(50), @codestring varchar(1000)) as

declare @tex varchar(2000)
declare @pos int
declare @readstate char(1) 
declare @nextchar char(1) 
declare @val varchar(50)

begin

set @val=''
set @readstate='F'
set @pos=0
set @tex = @codestring
while @pos<len(@tex)
begin
	set @pos = @pos +1
	set @nextchar=substring(@tex,@pos,1)
	if @nextchar=',' continue
	if @nextchar='''' 
	begin
		if @readstate='F' 
			begin
			set @readstate='T' 
			continue
			end
		else 
			begin
			insert into #act_codelist values (@codetype,@codename,@val)
			set @val=''
			set @readstate='F'  
			end
	end
	if @readstate='T'
	begin
		set @val= @val + @nextchar
	end		
end 
end
go

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[popcodelist]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[popcodelist]
GO
create procedure popcodelist as

declare @codedata varchar(2000)
declare @onecode varchar(50)
declare @codetype varchar(20)
declare @codename varchar(50)

declare getcodesql cursor local for
select 'RACE',c_name,c_dimcode from ncats_demographics where c_fullname like '\ACT\Demographics\Race\%'
union
select 'SEX',c_name,c_dimcode from ncats_demographics where c_fullname like '\ACT\Demographics\Sex\%'
union
select 'HISPANIC',c_name,c_dimcode from ncats_demographics where c_fullname like '\ACT\Demographics\Hispanic\Y%'

begin
delete from #act_codelist;
open getcodesql ;
fetch next from getcodesql  into @codetype,@codename,@codedata;
while @@fetch_status=0
begin	
 
	exec parsecode  @codetype,@codename,@codedata 
	fetch next from getcodesql  into @codetype,@codename,@codedata;
end

close getcodesql ;
deallocate getcodesql ;
end

go

-- Run the popcodelist procedure we just created
EXEC popcodelist
GO

-- Insert these into the #code_map table
insert into #code_map(code, local_code) 
select replace(replace(replace(replace(codename,'American Indian or Alaska Native','american_indian'),
                                                'yes','hispanic_latino'),
                                                'Native Hawaiian or Other Pacific Islander','hawaiian_pacific_islander'),
                                                'Black or African American','black'),code from #act_codelist
                                                
