#!/usr/bin/env sh

consul agent -config-file /etc/consul.d/client/consul_client.json -config-file /etc/consul.d/services/${CONSUL_SERVICE}.json -node ${CONSUL_NODE_NAME} -retry-interval 5s -retry-join ${CONSUL_SERVERS}
