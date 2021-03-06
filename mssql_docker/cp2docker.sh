# You must download the MSSQL JDBC JAR first from https://www.microsoft.com/en-us/download/details.aspx?id=57175
docker cp i2b2_mssql-ds.xml i2b2-wildfly:/opt/jboss/wildfly/standalone/deployments
docker cp mssql-jdbc-7.0.0.jre8.jar i2b2-wildfly:/opt/jboss/wildfly/standalone/deployments

# Turn on multi-fact
docker cp i2b2-wildfly:/opt/jboss/wildfly/standalone/configuration/crcapp/crc.properties crc.properties
sed -i 's/queryprocessor.multifacttable=false/queryprocessor.multifacttable=true/' crc.properties 
docker cp crc.properties i2b2-wildfly:/opt/jboss/wildfly/standalone/configuration/crcapp/

docker restart i2b2-wildfly