# Specify the base image for this container
FROM debian:buster

# Labels
LABEL mantainer="gbudau"

# Disable front-end, automatically check defaults
ENV DEBIAN_FRONTEND=noninteractive

# Variables
ARG db_root_password=db_pass123

# Update and install necessary packages
RUN apt-get -qq update \
 && apt-get -qq install \
    nginx \ 
    mariadb-server

# Secure the install of mysql
RUN service mysql start; \
    echo 'UPDATE mysql.user SET password=PASSWORD("${db_root_password}") WHERE User="root"' | mysql --user=root; \
    echo 'DELETE FROM mysql.user WHERE User=""' | mysql --user=root; \
    echo 'DELETE FROM mysql.user WHERE User="root" AND Host NOT IN ("localhost", "127.0.0.1", "::1")' | mysql --user=root; \
    echo 'DROP DATABASE IF EXISTS test' | mysql --user=root; \
    echo 'DELETE FROM mysql.db WHERE Db="test" OR Db="test\\_%"' | mysql --user=root; \
    echo 'FLUSH PRIVILEGES' | mysql --user=root

# Install Php
RUN apt-get -qq install \
    php-fpm \
    php-mysql

# Make new directory for testing
RUN mkdir /var/www/testing
COPY srcs/testing /etc/nginx/sites-available/
RUN ln -s /etc/nginx/sites-available/testing /etc/nginx/sites-enabled/testing
RUN unlink /etc/nginx/sites-enabled/default

# Command that will be run when starting the container
CMD service php7.3-fpm start && service mysql start && nginx && bash

# Expose ports
EXPOSE 80
EXPOSE 443
