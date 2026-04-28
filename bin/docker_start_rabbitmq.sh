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

docker volume create rabbitmq_data

docker run -d --rm \
  --name rabbitmq \
  -p 5672:5672 \
  -p 15672:15672 \
  -e RABBITMQ_DEFAULT_USER=guest \
  -e RABBITMQ_DEFAULT_PASS=guest \
  -v rabbitmq_data:/var/lib/rabbitmq \
  rabbitmq:management

#docker exec rabbitmq bash -c 'rabbitmqctl wait /var/lib/rabbitmq/mnesia/rabbit\@${HOSTNAME}.pid'
sleep 10
docker exec rabbitmq rabbitmqctl add_vhost two
docker exec rabbitmq rabbitmqctl set_permissions -p two guest ".*" ".*" ".*"

if [ "$tail_logs" = "true" ]; then
	docker logs -f rabbitmq
fi
