VERSION=latest
NAME=registry-auth
NO_CACHE=--no-cache=true

all: build push
build:
	docker build $(NO_CACHE) -t $(NAME):$(VERSION) -t docker.sunet.se/$(NAME):$(VERSION) .
update: NO_CACHE=
update: build
push:
	docker push docker.sunet.se/$(NAME):$(VERSION)
stable:
	docker tag -f $(NAME):stable $(NAME):stable-$(date --rfc-3339='date')
	docker tag -f $(NAME):$(VERSION) $(NAME):stable
