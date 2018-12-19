-- Set up MSSQL project
INSERT INTO "i2b2hive"."crc_db_lookup"("c_domain_id", "c_project_path", "c_owner_id", "c_db_fullschema", "c_db_datasource", "c_db_servertype", "c_db_nicename", "c_db_tooltip", "c_comment", "c_entry_date", "c_change_date", "c_status_cd")
VALUES('i2b2demo', '/MSSQL/', '@', 'dbo', 'java:/MSSQLDS', 'SQLSERVER', 'MSSQL', NULL, NULL, NULL, NULL, NULL)
GO
INSERT INTO "i2b2pm"."pm_project_data"("project_id", "project_name", "project_wiki", "project_key", "project_path", "project_description", "change_date", "entry_date", "changeby_char", "status_cd")
VALUES('MSSQL', 'localhost MSSQL', 'http://www.i2b2.org', NULL, '/MSSQL', NULL, NULL, NULL, NULL, 'A')
GO
INSERT INTO "i2b2pm"."pm_project_user_roles"("project_id", "user_id", "user_role_cd", "change_date", "entry_date", "changeby_char", "status_cd")
VALUES('MSSQL', 'AGG_SERVICE_ACCOUNT', 'USER', NULL, NULL, NULL, 'A')
GO
INSERT INTO "i2b2pm"."pm_project_user_roles"("project_id", "user_id", "user_role_cd", "change_date", "entry_date", "changeby_char", "status_cd")
VALUES('MSSQL', 'AGG_SERVICE_ACCOUNT', 'MANAGER', NULL, NULL, NULL, 'A')
GO
INSERT INTO "i2b2pm"."pm_project_user_roles"("project_id", "user_id", "user_role_cd", "change_date", "entry_date", "changeby_char", "status_cd")
VALUES('MSSQL', 'AGG_SERVICE_ACCOUNT', 'DATA_OBFSC', NULL, NULL, NULL, 'A')
GO
INSERT INTO "i2b2pm"."pm_project_user_roles"("project_id", "user_id", "user_role_cd", "change_date", "entry_date", "changeby_char", "status_cd")
VALUES('MSSQL', 'AGG_SERVICE_ACCOUNT', 'DATA_AGG', NULL, NULL, NULL, 'A')
GO
INSERT INTO "i2b2pm"."pm_project_user_roles"("project_id", "user_id", "user_role_cd", "change_date", "entry_date", "changeby_char", "status_cd")
VALUES('MSSQL', 'i2b2', 'MANAGER', NULL, NULL, NULL, 'A')
GO
INSERT INTO "i2b2pm"."pm_project_user_roles"("project_id", "user_id", "user_role_cd", "change_date", "entry_date", "changeby_char", "status_cd")
VALUES('MSSQL', 'i2b2', 'USER', NULL, NULL, NULL, 'A')
GO
INSERT INTO "i2b2pm"."pm_project_user_roles"("project_id", "user_id", "user_role_cd", "change_date", "entry_date", "changeby_char", "status_cd")
VALUES('MSSQL', 'i2b2', 'DATA_OBFSC', NULL, NULL, NULL, 'A')
GO
INSERT INTO "i2b2pm"."pm_project_user_roles"("project_id", "user_id", "user_role_cd", "change_date", "entry_date", "changeby_char", "status_cd")
VALUES('MSSQL', 'demo', 'USER', NULL, NULL, NULL, 'A')
GO
INSERT INTO "i2b2pm"."pm_project_user_roles"("project_id", "user_id", "user_role_cd", "change_date", "entry_date", "changeby_char", "status_cd")
VALUES('MSSQL', 'demo', 'DATA_DEID', NULL, NULL, NULL, 'A')
GO
INSERT INTO "i2b2pm"."pm_project_user_roles"("project_id", "user_id", "user_role_cd", "change_date", "entry_date", "changeby_char", "status_cd")
VALUES('MSSQL', 'demo', 'DATA_OBFSC', NULL, NULL, NULL, 'A')
GO
INSERT INTO "i2b2pm"."pm_project_user_roles"("project_id", "user_id", "user_role_cd", "change_date", "entry_date", "changeby_char", "status_cd")
VALUES('MSSQL', 'demo', 'DATA_AGG', NULL, NULL, NULL, 'A')
GO
INSERT INTO "i2b2pm"."pm_project_user_roles"("project_id", "user_id", "user_role_cd", "change_date", "entry_date", "changeby_char", "status_cd")
VALUES('MSSQL', 'demo', 'DATA_LDS', NULL, NULL, NULL, 'A')
GO
INSERT INTO "i2b2pm"."pm_project_user_roles"("project_id", "user_id", "user_role_cd", "change_date", "entry_date", "changeby_char", "status_cd")
VALUES('MSSQL', 'demo', 'EDITOR', NULL, NULL, NULL, 'A')
GO
INSERT INTO "i2b2pm"."pm_project_user_roles"("project_id", "user_id", "user_role_cd", "change_date", "entry_date", "changeby_char", "status_cd")
VALUES('MSSQL', 'demo', 'DATA_PROT', NULL, NULL, NULL, 'A')
GO
-- ont_db_lookup --
INSERT INTO i2b2hive.ont_db_lookup(c_domain_id, c_project_path, c_owner_id, c_db_fullschema, c_db_datasource, c_db_servertype, c_db_nicename, c_db_tooltip, c_comment, c_entry_date, c_change_date, c_status_cd)
  VALUES('i2b2demo', 'MSSQL/', '@', 'dbo', 'java:/MSSQLDS', 'SQLSERVER', 'MSSQL', NULL, NULL, NULL, NULL, NULL)
GO
-- work_db_lookup --
INSERT INTO i2b2hive.work_db_lookup(c_domain_id, c_project_path, c_owner_id, c_db_fullschema, c_db_datasource, c_db_servertype, c_db_nicename, c_db_tooltip, c_comment, c_entry_date, c_change_date, c_status_cd)
  VALUES('i2b2demo', 'MSSQL/', '@', 'dbo', 'java:/MSSQLDS', 'SQLSERVER', 'MSSQL', NULL, NULL, NULL, NULL, NULL)
GO
