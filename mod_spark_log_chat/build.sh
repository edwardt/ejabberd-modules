#!/bin/sh
EJABBERD_DEV=../ejabberd-dev/trunk
AMQP_DEV=../amqp_client
RABBITC_DEV=../rabbit_common
SPARK_APP_CONFIG=./apps/spark_common_util

erl -pa ${EJABBERD_DEV}/ebin ${SPARK_APP_CONFIG}/ebin ${AMQP_DEV}/ebin ${RABBITC_DEV}/ebin -pz ebin -make
