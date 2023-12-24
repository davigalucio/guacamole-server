GUAC_VERSION=1.5.4
TOMCAT_VERSION=9

GUAC_DB=guac_db
GUAC_DB_USER=guac_user
GUAC_DB_USER_PWD=guac_password

MYSQL_CONNECTOR_JAVA_VERSION=8.2.0

DEBIAN_VERSION_ID=$(cat /etc/*release* | grep VERSION_ID | cut -d '"' -f 2)

echo "deb http://deb.debian.org/debian/ bullseye main" >> /etc/apt/sources.list

apt update
apt-get install sudo wget mariadb-server build-essential uuid-dev freerdp2-dev -y
apt-get install libcairo2-dev libjpeg62-turbo-dev libtool-bin libossp-uuid-dev libavcodec-dev libavformat-dev libswscale-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libwebsockets-dev libpulse-dev libvorbis-dev libwebp-dev -y


sudo apt install -y tomcat$TOMCAT_VERSION
sudo systemctl enable --now tomcat$TOMCAT_VERSION

wget -P /opt/ https://dlcdn.apache.org/guacamole/$GUAC_VERSION/source/guacamole-server-"$GUAC_VERSION".tar.gz
tar -xzf /opt/guacamole-server-"$GUAC_VERSION".tar.gz -C /opt/
cd /opt/guacamole-server-"$GUAC_VERSION"

#export CFLAGS="-Wno-error"
#./configure --with-systemd-dir=/etc/systemd/system/ --disable-dependency-tracking

./configure --with-systemd-dir=/etc/systemd/system/ --disable-dependency-tracking --disable-guacenc

make
make install

sudo ldconfig
sudo systemctl daemon-reload
sudo systemctl enable --now guacd

echo GUACAMOLE_HOME=/etc/guacamole >> /etc/default/tomcat"$TOMCAT_VERSION"

mkdir -p /etc/guacamole/extensions
mkdir -p /etc/guacamole/lib



cat >> /etc/guacamole/config.sql << EOL
CREATE DATABASE $GUAC_DB;
CREATE USER '$GUAC_DB_USER'@'localhost' IDENTIFIED BY '$GUAC_DB_USER_PWD';
GRANT SELECT,INSERT,UPDATE,DELETE ON $GUAC_DB.* TO $GUAC_DB_USER@localhost;
FLUSH PRIVILEGES;
EOL

mysql -u root < /etc/guacamole/config.sql

mysql -u root -e "SELECT user FROM mysql.user;"
mysql -u root -e "show databases;"

#mysql -u root -e "CREATE DATABASE "$GUAC_DB";"
#mysql -u root -e "CREATE USER '$GUAC_DB_USER'@'localhost' IDENTIFIED BY '$GUAC_DB_USER_PWD';"
#mysql -u root -e "GRANT SELECT,INSERT,UPDATE,DELETE ON $GUAC_DB.* TO '$GUAC_DB_USER'@'localhost';"
#mysql -u root -e "FLUSH PRIVILEGES;"

wget -P /opt/ https://dlcdn.apache.org/guacamole/"$GUAC_VERSION"/binary/guacamole-auth-jdbc-"$GUAC_VERSION".tar.gz
tar -xf /opt/guacamole-auth-jdbc-"$GUAC_VERSION".tar.gz -C /opt/
cat /opt/guacamole-auth-jdbc-"$GUAC_VERSION"/mysql/schema/*.sql | mysql -u root $GUAC_DB
cp /opt/guacamole-auth-jdbc-"$GUAC_VERSION"/mysql/guacamole-auth-jdbc-mysql-"$GUAC_VERSION".jar /etc/guacamole/extensions/guacamole-auth-jdbc-mysql.jar

export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin


wget -P /opt/ https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j_"$MYSQL_CONNECTOR_JAVA_VERSION"-1debian"$DEBIAN_VERSION_ID"_all.deb
dpkg -i /opt/mysql-connector-j_"$MYSQL_CONNECTOR_JAVA_VERSION"-1debian"$DEBIAN_VERSION_ID"_all.deb


cp /usr/share/java/mysql-connector-java-"$MYSQL_CONNECTOR_JAVA_VERSION".jar /etc/guacamole/lib/mysql-connector.jar

cat >> /etc/guacamole/guacamole.properties << EOL
mysql-hostname: localhost
mysql-port: 3306
mysql-database: $GUAC_DB
mysql-username: $GUAC_DB_USER
mysql-password: $GUAC_DB_USER_PWD
EOL

cat >> /etc/guacamole/guacd.conf << EOL
[server]
bind_host = 0.0.0.0
bind_port = 4822
EOL

wget -P /opt/ https://dlcdn.apache.org/guacamole/"$GUAC_VERSION"/binary/guacamole-"$GUAC_VERSION".war
cp /opt/guacamole-"$GUAC_VERSION".war /etc/guacamole/guacamole.war
sudo ln -s /etc/guacamole/guacamole.war /var/lib/tomcat"$TOMCAT_VERSION"/webapps
#cp /etc/guacamole/guacamole.war /var/lib/tomcat"$TOMCAT_VERSION"/webapps

sudo systemctl restart guacd
sudo systemctl restart tomcat"$TOMCAT_VERSION"
