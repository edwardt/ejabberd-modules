#!/bin/bash

make_deps(){
	./deps/edown/make all
	./deps/goldrush/make all
	./deps/lager/make all
	./deps/parse_trans/make all
	./deps/mochiweb/make all
 	./deps/webmachine/make all
}
