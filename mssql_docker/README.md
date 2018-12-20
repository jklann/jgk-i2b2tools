# Add a local MSSQL i2b2 project to the Docker deployment

## Step 1
Deploy the [i2b2 Docker images](https://github.com/waghsk/i2b2-quickstart/wiki/Docker). As of 12/19/18, the latest wildfly (based on i2b2 v1.7.10) and multi_fact_table (1.7.09b) postgres images work best. I prefer to host the webclient in Apache on localhost, but if you do that, make surey you expose the appropriate port and change the db-lookup tables in Postgres.

```
docker network create i2b2-net
docker run -d  -p 5432:5432 --net i2b2-net --name i2b2-pg  i2b2/i2b2-pg:multi_fact_table
docker run -d -e DS_IP='i2b2-pg' -p8080:8080 --net i2b2-net --name i2b2-wildfly i2b2/i2b2-wildfly:latest
export IP=[PUBLIC_IP]
sudo docker exec -it i2b2-pg bash -c "export PUBLIC_IP=$IP;sh update_pm_cell_data.sh; "
```

And to use the local webclient:

```
Cd /var/www/html
git clone https://github.com/i2b2/i2b2-webclient.git
```

Edit ``i2b2_config_data.js`` to use localhost:8080

You might also find you need to change the port definition in the local pgsql db. Connect with your favorite Postgres client and execute:

```
UPDATE "i2b2pm"."pm_cell_data" SET "url"='http://localhost:8080/i2b2/services/QueryToolService/' WHERE "cell_id"='CRC' AND "project_path"='/';
UPDATE "i2b2pm"."pm_cell_data" SET "url"='http://localhost:8080/i2b2/services/FRService/' WHERE "cell_id"='FRC' AND "project_path"='/';
UPDATE "i2b2pm"."pm_cell_data" SET "url"='http://localhost:8080/i2b2/services/OntologyService/' WHERE "cell_id"='ONT' AND "project_path"='/';
UPDATE "i2b2pm"."pm_cell_data" SET "url"='http://localhost:8080/i2b2/services/WorkplaceService/' WHERE "cell_id"='WORK' AND "project_path"='/';
UPDATE "i2b2pm"."pm_cell_data" SET "url"='http://localhost:8080/i2b2/services/IMService/' WHERE "cell_id"='IM' AND "project_path"='/';
```

## Step 2
Set up [MSSQL in Docker](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-configure-docker?view=sql-server-2017) on the i2b2 Docker network.

``` 
docker run -e 'ACCEPT_EULA=Y' -e 'MSSQL_SA_PASSWORD=<PASSWORDHERE>' -p 1433:1433 -v sqlvolume:/var/opt/mssql --name mssql -d mcr.microsoft.com/mssql/server:2017-latest 
docker network connect i2b2-net mssql
```

You might want to change to SIMPLE recovery mode to save disk space:

```
USE [master] ;  
ALTER DATABASE [dbo] SET RECOVERY SIMPLE ;  
USE [dbo] ;
DBCC SHRINKFILE ('dbo_log', 1);
```

Now create the i2b2 user. Run this in an MSSQL client:

```
USE [master]
CREATE LOGIN [i2b2] WITH PASSWORD = N'i2b2r0cks!',
  DEFAULT_DATABASE = [dbo], CHECK_EXPIRATION = OFF, CHECK_POLICY = ON

USE [dbo]
CREATE USER [i2b2]
ALTER ROLE [db_owner] ADD MEMBER [i2b2]
```

Now install the i2b2 CRC, metadata, and workdata according to the [i2b2 documentation](https://community.i2b2.org/wiki/display/getstarted/Chapter+3.+Data+Installation)

## Step 3
Connect i2b2 to MSSQL:

a. Add the metadata for the project by running [create\_project\_pgsql](create_project_pgsql.sql) from a Postgres client.

b. Add the datasource to wildfly by running [cp2docker](cp2docker.sh) from the command line. 

## Backup and restore

You can [back up your MSSQL volume](https://docs.docker.com/storage/volumes) to make it easy to restore later if your Docker installation gets destroyed. For example:

Backup:
```
docker run --rm --volumes-from mssql -v ~:/backup ubuntu tar czvf /backup/mssql_backup.tgz /var/opt/mssql
```
