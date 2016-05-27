#!/bin/bash

blocked_services=(
	mysql
	rabbitmq-server
	memcached
	keystone
	glance-api
	glance-registry
	nova-api
	nova-cert
	nova-consoleauth
	nova-scheduler
	nova-conductor
	nova-novncproxy
	neutron-server
	neutron-metadata-agent
	libvirtd
	nova-compute
	neutron-dhcp-agent
)

# Ignore options (eg: --quiet)
case "$1" in
--*)
	shift
	;;
esac

case "$2" in
	start)
		for s in "${blocked_services[@]}"; do
			if [[ "$1" = "$s" ]]; then
				exit 101
			fi
		done
		;;
esac

exit 104
