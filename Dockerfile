# Specify the base image for this container
FROM debian:buster

# Labels
LABEL mantainer="gbudau"

# Disable front-end, automatically check defaults
ENV DEBIAN_FRONTEND=noninteractive

# Variables
ARG db_root_password=db_pass123
ARG wordpress_db=wordpress
ARG wordpress_user=wordpress_user
ARG wordpress_db_pass=wordpress_db_pass

# Update system and install nginx and mysql
RUN apt-get -qq update \
 && apt-get -qq install \
    nginx \ 
    mariadb-server

# Secure the installation of mysql
RUN service mysql start; \
    echo 'UPDATE mysql.user SET password=PASSWORD("${db_root_password}") WHERE User="root"' | mysql --user=root; \
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

# Create new database for wordpress
RUN service mysql start; \
    echo "CREATE DATABASE ${wordpress_db} DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci" | mysql --user=root; \
    echo "GRANT ALL ON ${wordpress_db}.* TO '${wordpress_user}'@'localhost' IDENTIFIED BY '${wordpress_db_pass}'" | mysql --user=root; \
    echo 'FLUSH PRIVILEGES' | mysql --user=root; \
    echo 'EXIT' | mysql --user=root

# Install PHP Extensions
RUN apt-get -qq update \
 && apt-get -qq install \
    php-curl \
    php-gd \ 
    php-intl \ 
    php-mbstring \
    php-soap \
    php-xml \
    php-xmlrpc \
    php-zip

# Make new directory for testing Wordpress, copy config file and link to sites-enabled
COPY srcs/nginx-default /etc/nginx/sites-available/default

# Command that will be run when starting the container
CMD service php7.3-fpm start && service mysql start && nginx && bash

# Expose ports
EXPOSE 80
EXPOSE 443
