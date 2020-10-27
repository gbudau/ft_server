# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: gbudau <gbudau@student.42.fr>              +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2020/03/09 12:17:49 by gbudau            #+#    #+#              #
#    Updated: 2020/10/27 14:24:40 by gbudau           ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

.PHONY: all
all: build run exec

.PHONY: build
build:
	docker build -t ft_server .

.PHONY: run
run:
	docker run --rm -d --name ft_server -p 443:443 -p 80:80 ft_server

.PHONY: autoindex
autoindex:
	docker run --env NGINX_AUTOINDEX=1 --rm -d --name ft_server -p 443:443 -p 80:80 ft_server

.PHONY: exec
exec:
	docker exec -u 0 -it ft_server bash

.PHONY: stop
stop:
	-docker stop ft_server

.PHONY: clean
clean: stop
	docker rmi ft_server

.PHONY: show
show:
	docker ps -a
	docker images -a

.PHONY: re
re: clean all
