VERSION=latest
NAME=registry-auth

all: build push
build:
	docker build --no-cache=true -t $(NAME):$(VERSION) .
	docker tag -f $(NAME):$(VERSION) docker.sunet.se/$(NAME):$(VERSION)
update:
	docker build -t $(NAME):$(VERSION) .
	docker tag -f $(NAME):$(VERSION) docker.sunet.se/$(NAME):$(VERSION)
push:
	docker push docker.sunet.se/$(NAME):$(VERSION)
stable:
	docker tag -f $(NAME):stable $(NAME):stable-$(date --rfc-3339='date')
	docker tag -f $(NAME):$(VERSION) $(NAME):stable
