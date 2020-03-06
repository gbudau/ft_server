# Specify the base image for this container
FROM debian:buster

# Labels
LABEL mantainer="gbudau"

# Disable front-end, automatically check defaults
ENV DEBIAN_FRONTEND=noninteractive

# Variables
ARG MYSQL_ROOT_PASSWORD=mysql_password
ARG WORDPRESS_DATABASE=wordpress
ARG WORDPRESS_DATABASE_USER=wordpress_database_user
ARG WORDPRESS_DATABASE_PASS=wordpress_database_pass

# Update system and install nginx and mariaDB
RUN apt-get -qq update \
 && apt-get -qq install \
    nginx \ 
    mariadb-server

# Secure the installation of mysql
RUN service mysql start; \
    echo 'UPDATE mysql.user SET password=PASSWORD("${MYSQL_ROOT_PASSWORD}") WHERE User="root"' | mysql --user=root; \
    echo 'DELETE FROM mysql.user WHERE User=""' | mysql --user=root; \
    echo 'DELETE FROM mysql.user WHERE User="root" AND Host NOT IN ("localhost", "127.0.0.1", "::1")' | mysql --user=root; \
    echo 'DROP DATABASE IF EXISTS test' | mysql --user=root; \
    echo 'DELETE FROM mysql.db WHERE Db="test" OR Db="test\\_%"' | mysql --user=root; \
    echo 'FLUSH PRIVILEGES' | mysql --user=root; \
    echo 'EXIT' | mysql --user=root

# Install PHP
RUN apt-get -qq install \
    php-fpm \
    php-mysql

# Create new database for WordPress
RUN service mysql start; \
    echo "CREATE DATABASE ${WORDPRESS_DATABASE} DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci" | mysql --user=root; \
    echo "GRANT ALL ON ${WORDPRESS_DATABASE}.* TO '${WORDPRESS_DATABASE_USER}'@'localhost' IDENTIFIED BY '${WORDPRESS_DATABASE_PASS}'" | mysql --user=root; \
    echo 'FLUSH PRIVILEGES' | mysql --user=root; \
    echo 'EXIT' | mysql --user=root

# Install PHP Extensions
RUN apt-get -qq install \
    php-curl \
    php-gd \ 
    php-intl \ 
    php-mbstring \
    php-soap \
    php-xml \
    php-xmlrpc \
    php-zip

# Install other packages
RUN apt-get -qq install \
    ssl-cert \
    wget \
    unzip \
    curl \
    ed \
    vim

# Install and configure WordPress
RUN wget -q https://wordpress.org/latest.tar.gz -P /tmp/ \
 && tar -xzf tmp/latest.tar.gz -C tmp \
 && cp -r tmp/wordpress/* /var/www/html/ \
 && cp var/www/html/wp-config-sample.php var/www/html/wp-config.php \
 && rm -rf tmp/* \
 && SALT=$(curl -sL https://api.wordpress.org/secret-key/1.1/salt/) \
 && STRING='put your unique phrase here' \
 && printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s var/www/html/wp-config.php \
 && sed -i -e "s/database_name_here/${WORDPRESS_DATABASE}/" -e "s/username_here/${WORDPRESS_DATABASE_USER}/g" -e "s/password_here/${WORDPRESS_DATABASE_PASS}/g" var/www/html/wp-config.php \
 && mkdir var/www/html/uploads \
 && chown -R www-data:www-data /var/www/html/ 

# Copy nginx config
COPY srcs/nginx-default /etc/nginx/sites-available/default

# Start services
CMD service php7.3-fpm start && service mysql start && nginx && bash

# Expose ports
EXPOSE 80
EXPOSE 443
