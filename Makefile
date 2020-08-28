# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: gbudau <gbudau@student.42.fr>              +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2020/03/09 12:17:49 by gbudau            #+#    #+#              #
#    Updated: 2020/08/28 14:54:25 by gbudau           ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

.PHONY: all
all: build run exec

.PHONY: build
build:
	docker build -t ft_server .

.PHONY: run
run:
	docker run --rm -d -p 443:443 -p 80:80 ft_server

.PHONY: autoindex
autoindex:
	docker run --env NGINX_AUTOINDEX=1 --rm -d -p 443:443 -p 80:80 ft_server

.PHONY: exec
exec:
	docker exec -u 0 -it $$(docker ps | sed -n '2p' | tr -s ' ' | cut -f 1 -d ' ') bash

.PHONY: stop
stop:
	-docker stop $$(docker ps | grep 'Up ' | tr -s ' ' | cut -f 1 -d ' ' | tr '\n' ' ')

.PHONY: clean
clean: stop
	docker rmi $$(docker images | tr -s ' ' | tail -n +2 | cut -f 3 -d ' ')

.PHONY: show
show:
	docker ps -a
	docker images -a

.PHONY: re
re: clean all
