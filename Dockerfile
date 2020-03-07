# Specify the base image for this container
FROM debian:buster

# Labels
LABEL mantainer="gbudau"
LABEL usage.build="docker build -t [image name] ."
LABEL usage.run="docker run -it -p 80:80 -p 443:443 [image id/name]"
LABEL usage.noninteractive.modify="Add 'sleep infinity' instead of 'bash' in CMD instruction"
LABEL usage.noninteractive="docker run -d -p 80:80 -p 443:443"
LABEL usage.noninteractive.stop="docker stop [container id/name]"

# Variables
ARG MYSQL_ROOT_PASSWORD=mysql_password
ARG WORDPRESS_DATABASE=wordpress
ARG WORDPRESS_DATABASE_USER=wordpress_database_user
ARG WORDPRESS_DATABASE_PASS=wordpress_database_pass
ARG WORDPRESS_URL=localhost
ARG WORDPRESS_SITE_TITLE=ft_server
ARG WORDPRESS_ADMIN_NAME=wordpress_admin
ARG WORDPRESS_ADMIN_EMAIL=test@test.com
ARG WORDPRESS_ADMIN_PASSWORD=wordpress_password
ARG PHPMYADMIN_VERSION=5.0.1
ARG PMA_USER_DATABASE_PASSWORD=pma_user_database_password
ARG DATABASE_USER=database_user
ARG DATABASE_USER_PASSWORD=database_password
# Set this to [any value] for autoindex on or don't set for autoindex off also can be set at build time with --build-arg NGINX_AUTOINDEX=[any value]
ARG NGINX_AUTOINDEX

# Update system and install nginx and mariaDB
RUN apt-get -qq update \
 && apt-get -qq install \
    nginx \ 
    mariadb-server

# Secure the installation of mysql
RUN service mysql start \
 && echo "UPDATE mysql.user SET password=PASSWORD('${MYSQL_ROOT_PASSWORD}') WHERE User='root';" | mysql --user=root \
 && echo "DELETE FROM mysql.user WHERE User='';" | mysql --user=root \
 && echo "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" | mysql --user=root \
 && echo "DROP DATABASE IF EXISTS test;" | mysql --user=root \
 && echo "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" | mysql --user=root

# Install PHP
RUN apt-get -qq install \
    php-fpm \
    php-mysql

# Create new database for WordPress
RUN service mysql start \
 && echo "CREATE DATABASE ${WORDPRESS_DATABASE} DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;" | mysql --user=root \
 && echo "GRANT ALL ON ${WORDPRESS_DATABASE}.* TO '${WORDPRESS_DATABASE_USER}'@'localhost' IDENTIFIED BY '${WORDPRESS_DATABASE_PASS}';" | mysql --user=root

# Install PHP Extensions
RUN apt-get -qq install \
    php-curl \
    php-gd \ 
    php-intl \ 
    php-mbstring \
    php-soap \
    php-xml \
    php-xmlrpc \
    php-zip \
 && sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0;/g' etc/php/7.3/fpm/php.ini

# Install other packages
RUN apt-get -qq install \
    ssl-cert \
    openssl \
    wget \
    ed \
    vim

# Install and configure WordPress
RUN wget -q https://wordpress.org/latest.tar.gz -P tmp \
 && tar xzf tmp/latest.tar.gz -C tmp \
 && cp -r tmp/wordpress/* /var/www/html/ \
 && cp var/www/html/wp-config-sample.php var/www/html/wp-config.php \
 && SALT=$(wget -qO- https://api.wordpress.org/secret-key/1.1/salt/) \
 && STRING='put your unique phrase here' \
 && printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s var/www/html/wp-config.php \
 && sed -i -e "s/database_name_here/${WORDPRESS_DATABASE}/" -e "s/username_here/${WORDPRESS_DATABASE_USER}/g" -e "s/password_here/${WORDPRESS_DATABASE_PASS}/g" var/www/html/wp-config.php \
 && mkdir var/www/html/uploads \
 && wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -P /tmp/ \
 && chmod +x tmp/wp-cli.phar \
 && mv tmp/wp-cli.phar usr/local/bin/wp \
 && service mysql start \
 && wp core install --url=${WORDPRESS_URL} --title=${WORDPRESS_SITE_TITLE} --admin_name=${WORDPRESS_ADMIN_NAME} --admin_email=${WORDPRESS_ADMIN_EMAIL} --admin_password=${WORDPRESS_ADMIN_PASSWORD} --allow-root --path='var/www/html/' --skip-email --quiet \
 && wp plugin install really-simple-ssl --activate --allow-root --path=/var/www/html --quiet \
 && wp rsssl activate_ssl --allow-root --path=/var/www/html --quiet \
 && service mysql stop \
 && chown -R www-data:www-data /var/www/html/

# Install phpMyAdmin
RUN wget -q https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz -P tmp \
 && tar xzf tmp/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz -C tmp \
 && mv tmp/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages/ /usr/share/phpmyadmin \
 && mkdir -p /var/lib/phpmyadmin/tmp \
 && chown -R www-data:www-data /var/lib/phpmyadmin \
 && randomBlowfishSecret=$(openssl rand -base64 32) \
 && sed -e "s|cfg\['blowfish_secret'\] = ''|cfg['blowfish_secret'] = '$randomBlowfishSecret'|" -e '/controluser/,/End/ s/^\/\///g' /usr/share/phpmyadmin/config.sample.inc.php > /usr/share/phpmyadmin/config.inc.php \
 && sed -i "s/pmapass/${PMA_USER_DATABASE_PASSWORD}/g" /usr/share/phpmyadmin/config.inc.php \
 && echo "\$cfg['TempDir'] = '/var/lib/phpmyadmin/tmp';" >> /usr/share/phpmyadmin/config.inc.php \
 && service mysql start \
 && mariadb < /usr/share/phpmyadmin/sql/create_tables.sql \
 && echo "GRANT SELECT, INSERT, UPDATE, DELETE ON phpmyadmin.* TO 'pma'@'localhost' IDENTIFIED BY '${PMA_USER_DATABASE_PASSWORD}';" | mysql --user=root \
 && echo "GRANT ALL PRIVILEGES ON *.* TO '${DATABASE_USER}'@'localhost' IDENTIFIED BY '${DATABASE_USER_PASSWORD}';" | mysql --user=root \
 && ln -s /usr/share/phpmyadmin /var/www/html/ \
 && rm -rf tmp/*

# Copy nginx config and enable autoindex if NGINX_AUTOINDEX is set to on
COPY srcs/nginx-default /etc/nginx/sites-available/default
RUN if [ "off$NGINX_AUTOINDEX" = "off" ] ; then echo "Autoindex is set  to off"; else sed -i -e "s/autoindex off;/autoindex on;/" -e "s/index index.php;/index html;/" /etc/nginx/sites-available/default; fi

# Start services
CMD service php7.3-fpm start && service mysql start && nginx && bash

# Expose ports
EXPOSE 80
EXPOSE 443
