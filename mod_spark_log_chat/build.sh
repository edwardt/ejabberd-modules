#!/bin/sh
EJABBERD_DEV=../ejabberd-dev/trunk
AMQP_DEV=../amqp_client
RABBITC_DEV=../rabbit_common
SPARK_APP_CONFIG=./apps/spark_common_util
JSON=./json_rec/lib
DEPS=./deps/*/ebin

erl -pa ${EJABBERD_DEV}/ebin -pa ${JSON}/ebin -pa ${SPARK_APP_CONFIG}/ebin ${AMQP_DEV}/ebin -pa ${RABBITC_DEV}/ebin -pa ${DEPS} -pz ebin -make
