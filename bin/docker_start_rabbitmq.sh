#!/bin/sh

# abort on any error
set -e

tail_logs=false

for arg in "$@"
do
	if [ "$arg" = "--tail" ]; then
		tail_logs=true
	fi
done

docker compose -f docker/docker-compose.yml up -d
docker exec rabbitmq bash -c 'rabbitmqctl wait /var/lib/rabbitmq/mnesia/rabbit\@${HOSTNAME}.pid'
docker exec rabbitmq rabbitmqctl add_vhost two
docker exec rabbitmq rabbitmqctl set_permissions -p two guest ".*" ".*" ".*"

if [ "$tail_logs" = "true" ]; then
	docker logs -f rabbitmq
fi
