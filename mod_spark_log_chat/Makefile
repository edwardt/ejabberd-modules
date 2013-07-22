
# Set the ERL environnement variable if you want to use a specific erl

ERL ?= $(shell which erl)
EJABBERD_DEV ?= ../ejabberd-dev/trunk
SPARK_APP_CONFIG ?=./apps/spark_common_util
AMQP_DEV ?=../amqp_client
RABBITC_DEV ?=../rabbit_common
EDOWN ?=./json_rec/deps/edown
PARSET ?=./json_rec/deps/parse_trans
JSON_REC ?=./json_rec


all:
	$(ERL) -pa $(EJABBERD_DEV)/ebin $(SPARK_APP_CONFIG)/ebin $(AMQP_DEV)/ebin  $(RABBITC_DEV)/ebin $(EDOWN)/ebin $(PARSET)/ebin $(JSON_REC)/ebin -make

clean:
	rm -f ebin/*.*

dist-clean: clean
	find . \( -name \*~ -o -name *.swp \) -exec rm -f {} \;
