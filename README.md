# Instalação do Guacamole Server no Linux Debian 12 com Maria DB e Proxy Reverso com NGINX com Autenticação TOTP

apt install -y git

git clone https://github.com/davigalucio/guacamole-server.git

sh guacamole-server/INSTALL.SH


# Para resetar o TOTP do usuário, use o comando abaixo: Exemplo do usuário guacadmin:

sh guacamole-server/RESET_TOTP.sh guacadmin

# Informações da instalação:

GUAC_VERSION=1.5.4

TOMCAT_VERSION=9

GUAC_DB=guac_db

GUAC_DB_USER=guac_user

GUAC_DB_USER_PWD=guac_password

Linux Debian 12 minimal: Instalação minima + SSH
Link de download:
https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.4.0-amd64-netinst.iso

