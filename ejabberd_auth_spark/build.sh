#!/bin/sh

ERLC_FLAGS=
SOURCES=$./src/*.erl
HEADERS=$./src/*.hrl
DEPENDENCY=../../ejabberd-dev/trunk/ebin
OBJECTS=$SOURCES:src/%.erl=ebin/%.beam
 
rm -rfv $OBJECTS

erl -pa $DEPENDENCY -pz ebin -make

erl -noshell -pa ebin -eval 'eunit:test("ebin",[verbose])' -s init stop
