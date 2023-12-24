# Instalação do Guacamole Server no Linux Debian 12 com Maria DB e Proxy Reverso com NGINX com Autenticação TOTP

apt install -y git

git clone https://github.com/davigalucio/guacamole-server.git

sh guacamole-server/INSTALL.SH


# Para resetar o TOTP do usuário, use o comando abaixo: Exemplo do usuário guacadmin:

sh guacamole-server/RESET_TOTP.sh guacadmin
