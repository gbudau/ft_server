.PHONY: build
build:
	docker build -t ft_server .

.PHONY: run
run:
	docker run -it -p 80:80 ft_server

.PHONY: clean
clean:
	docker rm $$(docker ps -a -q)

.PHONY: fclean
fclean: 
	docker rmi $$(docker images | grep -v debian | tr -s ' ' | tail -n +2 | cut -f 3 -d ' ')
