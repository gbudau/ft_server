# Specify the base image for this container
FROM debian:buster

# Labels
LABEL mantainer="gbudau"

# Disable front-end, automatically check defaults
ENV DEBIAN_FRONTEND=noninteractive

# Update and install necessary packages
RUN apt-get -qq update \
 && apt-get -qq install \
    nginx \ 
    mariadb-server

# Copy the script that will run when starting the container
COPY srcs/start.sh .

# Command that will be run when starting the container
CMD ["bash", "start.sh"]

# Expose ports
EXPOSE 80
EXPOSE 443
