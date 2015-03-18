all: build push
build:
	docker build --no-cache=true -t registry-auth .
	docker tag -f registry-auth docker.sunet.se/registry-auth
push:
	docker push docker.sunet.se/registry-auth
