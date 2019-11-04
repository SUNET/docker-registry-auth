VERSION=latest
NAME=registry-auth
NO_CACHE=--no-cache=true
PULL=

all: build push
build:
	docker build $(PULL) $(NO_CACHE) -t docker.sunet.se/sunet/docker-$(NAME):$(VERSION) .
update: NO_CACHE=
update: build
pull:
	$(eval PULL=--pull)
push:
	docker push docker.sunet.se/sunet/docker-$(NAME):$(VERSION)
stable:
	docker tag -f docker.sunet.se/sunet/docker-$(NAME):stable docker.sunet.se/sunet/docker-$(NAME):stable-$(date --rfc-3339='date')
	docker tag -f docker.sunet.se/sunet/docker-$(NAME):$(VERSION) docker.sunet.se/sunet/docker-$(NAME):stable

SERVER_NAME=docker.example.com
CLIENT_NAME=client

$(SERVER_NAME).crt $(SERVER_NAME).key:
	openssl req -x509 -newkey rsa:4096 -keyout $(SERVER_NAME).key -nodes -out $(SERVER_NAME).crt -days 3650 -subj "/CN=$(SERVER_NAME)"
$(SERVER_NAME).crt: $(SERVER_NAME).key

$(CLIENT_NAME).csr $(CLIENT_NAME).key:
	openssl req -new -newkey rsa:4096 -keyout $(CLIENT_NAME).key -nodes -out $(CLIENT_NAME).csr -subj "/CN=$(CLIENT_NAME)"
$(CLIENT_NAME).csr: $(CLIENT_NAME).key

$(CLIENT_NAME).cert: $(CLIENT_NAME).csr $(SERVER_NAME).crt $(SERVER_NAME).key
	openssl x509 -req -in $(CLIENT_NAME).csr -CA $(SERVER_NAME).crt -CAkey $(SERVER_NAME).key -set_serial 1 -out $(CLIENT_NAME).cert -days 3650 -sha256

run_registry:
	docker run -i --rm --name registry registry

run_registry_auth: $(SERVER_NAME).crt $(SERVER_NAME).key
	docker run -i --rm --name $(NAME) --link registry -p 443:443 -e SERVER_NAME=$(SERVER_NAME) $(DEBUG_registry_auth_ssl) -v $(PWD)/$(SERVER_NAME).key:/etc/ssl/private/$(SERVER_NAME).key -v $(PWD)/$(SERVER_NAME).crt:/etc/ssl/certs/$(SERVER_NAME).crt -v $(PWD)/$(SERVER_NAME).crt:/etc/ssl/certs/$(SERVER_NAME)-chain.crt -v $(PWD)/$(SERVER_NAME).crt:/etc/ssl/certs/$(SERVER_NAME)-client-ca.crt docker.sunet.se/sunet/docker-$(NAME):$(VERSION)

test_registry_auth_ssl_conf: DEBUG_registry_auth_ssl=-v $(PWD)/registry-auth-ssl.conf:/etc/apache2/sites-available/registry-auth-ssl.conf
test_registry_auth_ssl_conf: run_registry_auth

test_curl: $(CLIENT_NAME).cert $(CLIENT_NAME).key
	curl -v --fail -X POST --insecure --cacert $(SERVER_NAME).crt --cert $(CLIENT_NAME).cert --key $(CLIENT_NAME).key https://$(SERVER_NAME)/v2/test/blobs/uploads/

install_client_certs: $(SERVER_NAME).crt $(CLIENT_NAME).cert $(CLIENT_NAME).key
	mkdir -p /etc/docker/certs.d/$(SERVER_NAME)
	cp $(CLIENT_NAME).cert $(CLIENT_NAME).key  /etc/docker/certs.d/$(SERVER_NAME)/
	cp $(SERVER_NAME).crt /etc/docker/certs.d/$(SERVER_NAME)/ca.crt

clean_certs:
	rm -f $(CLIENT_NAME).cert $(CLIENT_NAME).csr $(CLIENT_NAME).key $(SERVER_NAME).crt $(SERVER_NAME).key

set_read_only:
	docker exec $(NAME) bash -c 'touch /read-only ; apache2ctl -k graceful'

unset_read_only:
	docker exec $(NAME) bash -c 'rm -f /read-only ; apache2ctl -k graceful'

test:
	grep $(SERVER_NAME) /etc/hosts
	./test.sh
