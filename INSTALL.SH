######################################
# Informações da Instalação          #
######################################
GUAC_VERSION=1.5.4
TOMCAT_VERSION=9

######################################
# Informações do Banco de Dados      #
######################################
GUAC_DB=guac_db
GUAC_DB_USER=guac_user
GUAC_DB_USER_PWD=guac_password

######################################
# Informação do Conector Mysql Java  #
######################################
MYSQL_CONNECTOR_JAVA_VERSION=8.2.0

######################################
# Informação da versão do Debian     #
######################################

DEBIAN_VERSION_ID=$(cat /etc/*release* | grep VERSION_ID | cut -d '"' -f 2)

######################################
# Informação do IP atual             #
######################################
ip4=$(hostname -I | cut -d '.' -f 4 | cut -d ' ' -f 1)
ip3=$(hostname -I | cut -d '.' -f 3 | cut -d ' ' -f 1)
ip2=$(hostname -I | cut -d '.' -f 2 | cut -d ' ' -f 1)
ip1=$(hostname -I | cut -d '.' -f 1 | cut -d ' ' -f 1)

######################################
# Repositório Bullseye par o TomCat9 #
######################################
echo "deb http://deb.debian.org/debian/ bullseye main" >> /etc/apt/sources.list

######################################
# Instalação dos Pacotes             #
######################################
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

######################################
# Instalação NGINX com Proxy Reverso #
######################################

sudo apt install nginx -y

cat <<'EOF'>> /etc/nginx/sites-available/guacamole
server {
    listen      80;
    server_name IP_HOST;
    #rewrite     ^   https://$server_name$request_uri? permanent;
#}

#server {
    #listen      443 ssl http2;
    #server_name localhost;

    root /var/www/html;
    index index.html;

    location / {
       try_files $uri $uri/ =404;
    }

    #ssl_certificate /etc/letsencrypt/live/example.io/fullchain.pem;
    #ssl_certificate_key /etc/letsencrypt/live/example.io/privkey.pem;

    access_log /var/log/nginx/guacamole-access.log;
    error_log /var/log/nginx/guacamole-error.log;

    location /guacamole/ {
        proxy_pass http://127.0.0.1:8080/guacamole/;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_connection;
        access_log off;
    }
}
EOF

sudo sed -i "s/IP_HOST/$ip1.$ip2.$ip3.$ip4/g" /etc/nginx/sites-available/guacamole

sudo ln -s /etc/nginx/sites-available/guacamole /etc/nginx/sites-enabled/
sudo nginx -t

sudo systemctl restart nginx

######################################
# Autenticação duplo Fator TOTP      #
######################################

wget -P /opt/ https://dlcdn.apache.org/guacamole/"$GUAC_VERSION"/binary/guacamole-auth-totp-"$GUAC_VERSION".tar.gz
tar -zxf /opt/guacamole-auth-totp-"$GUAC_VERSION".tar.gz -C /opt/
cp /opt/guacamole-auth-totp-"$GUAC_VERSION"/guacamole-auth-totp-"$GUAC_VERSION".jar /etc/guacamole/extensions/

####################################
## CORREÇÃO DE FALHA DE LOGIN RDP ##
####################################
cp /etc/systemd/system/guacd.service /etc/systemd/system/guacd.service.bkp
sudo sed -i "s/User=daemon/User=root/g" /etc/systemd/system/guacd.service

sudo systemctl daemon-reload
sudo systemctl restart guacd
sudo systemctl restart tomcat"$TOMCAT_VERSION"

echo
echo "Instalação concluída!"
echo
echo "Apache Guacamole Server + MariaDB + Proxy Reverso NGNIX + Autenticação duplo Fator TOTP"
echo
echo "Acesse via broswer http://$ip1.$ip2.$ip3.$ip4/guacamole"
echo
echo "Usuario: guacadmin"
echo "Senha: guacadmin"
echo
