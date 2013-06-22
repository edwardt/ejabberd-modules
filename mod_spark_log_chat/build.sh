#!/bin/sh
EJABBERD_DEV=../ejabberd-dev/trunk
AMQP_DEV=../amqp_client
RABBITC_DEV=../rabbit_common

erl -pa ${EJABBERD_DEV}/ebin ${AMQP_DEV}/ebin ${RABBITC_DEV}/ebin -pz ebin -make