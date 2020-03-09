# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: gbudau <gbudau@student.42.fr>              +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2020/03/09 12:18:06 by gbudau            #+#    #+#              #
#    Updated: 2020/03/09 12:18:13 by gbudau           ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

### Specify the base image for this container
FROM debian:buster

### Labels
LABEL mantainer="gbudau"

### Variables
# Password for root user of mysql database
ARG MYSQL_ROOT_PASSWORD=mysql_password
# Wordpress database configuration
ARG WORDPRESS_DATABASE=wordpress
ARG WORDPRESS_DATABASE_USER=wordpress_database_admin
ARG WORDPRESS_DATABASE_PASS=wordpress_database_pass
# Wordpress configuration: site url, site name, admin id, admin email, admin password
ARG WORDPRESS_URL=localhost
ARG WORDPRESS_SITE_TITLE=ft_server
ARG WORDPRESS_ADMIN_NAME=wordpress_admin
ARG WORDPRESS_ADMIN_EMAIL=test@test.com
ARG WORDPRESS_ADMIN_PASSWORD=wordpress_password
# PhpMyAdmin version
ARG PHPMYADMIN_VERSION=5.0.1
# Password for the default user for PhpMyAdmin 'pma'
ARG PMA_USER_DATABASE_PASSWORD=pma_user_database_password
# Extra user for mysql database
ARG DATABASE_USER=database_admin
ARG DATABASE_USER_PASSWORD=database_password
# Set this to [any value] for autoindex on or keep it unset for autoindex off
ARG NGINX_AUTOINDEX=on

### Update system and install nginx, mysql, php, and additional packages
RUN apt-get -qq update \
 && apt-get -qq install \
    nginx \ 
    mariadb-server \
    php-fpm \
    php-mysql \
    php-curl \
    php-intl \ 
    php-mbstring \
    php-json \
    php-gd \
    php-soap \
    php-xml \
    php-xmlrpc \
    php-imagick \
    php-zip \
    ssl-cert \
    openssl \
    wget

### Copy nginx config from host to image
COPY srcs/nginx-default /etc/nginx/sites-available/default

### Set autoindex on/off, secure the installation of PHP + mysql and create database for Wordpress
RUN if [ -n "${NGINX_AUTOINDEX}" ] ; then sed -i "s/autoindex off;/autoindex on;/" /etc/nginx/sites-available/default; fi \
 && sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0;/g' etc/php/7.3/fpm/php.ini \
 && service mysql start \
 && mysql -e "UPDATE mysql.user SET password=PASSWORD('${MYSQL_ROOT_PASSWORD}') WHERE User='root';" \
 && mysql -e "DELETE FROM mysql.user WHERE User='';" \
 && mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" \
 && mysql -e "DROP DATABASE IF EXISTS test;" \
 && mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" \
 && mysql -e "CREATE DATABASE ${WORDPRESS_DATABASE} DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;" \
 && mysql -e "GRANT ALL ON ${WORDPRESS_DATABASE}.* TO '${WORDPRESS_DATABASE_USER}'@'localhost' IDENTIFIED BY '${WORDPRESS_DATABASE_PASS}';" \
 && sleep 1 \
 && service mysql stop

### Install and configure WordPress
RUN wget -q https://wordpress.org/latest.tar.gz -P tmp \
 && tar xzf tmp/latest.tar.gz -C tmp \
 && cp -r tmp/wordpress/* /var/www/html/ \
 && cd /var/www/html \
 && wget -q https://api.wordpress.org/secret-key/1.1/salt/ -O salt \
 && csplit -s wp-config-sample.php '/AUTH_KEY/' '/NONCE_SALT/+1' \
 && cat xx00 salt xx02 > wp-config.php \
 && rm salt xx00 xx01 xx02 \
 && cd / \
 && sed -i -e "s/database_name_here/${WORDPRESS_DATABASE}/" -e "s/username_here/${WORDPRESS_DATABASE_USER}/" -e "s/password_here/${WORDPRESS_DATABASE_PASS}/" var/www/html/wp-config.php \
 && mkdir var/www/html/uploads var/www/html/index \
 && wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -P /tmp/ \
 && chmod +x tmp/wp-cli.phar \
 && mv tmp/wp-cli.phar usr/local/bin/wp \
 && service mysql start \
 && wp core install --url=${WORDPRESS_URL} --title=${WORDPRESS_SITE_TITLE} --admin_name=${WORDPRESS_ADMIN_NAME} --admin_email=${WORDPRESS_ADMIN_EMAIL} --admin_password=${WORDPRESS_ADMIN_PASSWORD} --allow-root --path='var/www/html/' --skip-email --quiet \
 && wp theme install twentyseventeen --activate --allow-root --path=/var/www/html --quiet \
 && wp plugin uninstall hello --path=var/www/html/ --allow-root --quiet \
 && wp plugin uninstall akismet --path=var/www/html/ --allow-root --quiet \
 && wp theme delete twentysixteen --allow-root --path=/var/www/html --quiet \
 && wp theme delete twentynineteen --allow-root --path=/var/www/html --quiet \
 && wp theme delete twentytwenty --allow-root --path=/var/www/html --quiet \
 && wp search-replace 'Just another WordPress site' 'Just another Wordp... or maybe not!' --allow-root --path=var/www/html --quiet \
 && wp search-replace 'Hello world!' '42 Madrid' --allow-root --path=var/www/html --quiet \
 && wp search-replace 'A WordPress Commenter' 'A Programmer' --allow-root --path=var/www/html --quiet \
 && wp search-replace 'Welcome to WordPress. This is your first post. Edit or delete it, then start writing!' 'In progress ...' --allow-root --path=var/www/html --quiet \
 && service mysql stop \
 && chown -R www-data:www-data /var/www/html/

### Install phpMyAdmin
RUN wget -q https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz -P tmp \
 && tar xzf tmp/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz -C tmp \
 && mv tmp/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages/ /usr/share/phpmyadmin \
 && mkdir -p /var/lib/phpmyadmin/tmp \
 && chown -R www-data:www-data /var/lib/phpmyadmin \
 && randomBlowfishSecret=$(openssl rand -base64 32) \
 && sed -e "s|cfg\['blowfish_secret'\] = ''|cfg['blowfish_secret'] = '$randomBlowfishSecret'|" -e '/controluser/,/End/ s/^\/\///g' /usr/share/phpmyadmin/config.sample.inc.php > /usr/share/phpmyadmin/config.inc.php \
 && sed -i "s/pmapass/${PMA_USER_DATABASE_PASSWORD}/" /usr/share/phpmyadmin/config.inc.php \
 && echo "\$cfg['TempDir'] = '/var/lib/phpmyadmin/tmp';" >> /usr/share/phpmyadmin/config.inc.php \
 && service mysql start \
 && mariadb < /usr/share/phpmyadmin/sql/create_tables.sql \
 && mysql -e "GRANT SELECT, INSERT, UPDATE, DELETE ON phpmyadmin.* TO 'pma'@'localhost' IDENTIFIED BY '${PMA_USER_DATABASE_PASSWORD}';" \
 && mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${DATABASE_USER}'@'localhost' IDENTIFIED BY '${DATABASE_USER_PASSWORD}';" \
 && service mysql stop \
 && ln -s /usr/share/phpmyadmin /var/www/html/ \
 && rm -rf tmp/*

### Copy image used for WordPress site
COPY srcs/header.jpg /var/www/html/wp-content/themes/twentyseventeen/assets/images 

### Start services
CMD service php7.3-fpm start && service mysql start && nginx && tail -f /dev/null

### Ports that needs to be exposed at run time with -p [host port]:[container port] // If ports are not exposed comment lines 82-95 to setup WordPress with correct URL
EXPOSE 80
EXPOSE 443
