#!/bin/bash
echo on
make_deps(){
	
	@(cd ./deps/edown/; ./make all)
	@(cd ./deps/goldrush; ./make all)
	@(cd ./deps/lager; ./make all)
	@(cd ./deps/parse_trans; ./make all)
	@(cd ./deps/mochiweb; ./make all)
 	@(cd ./deps/webmachine; ./make all)
}
echo "Building deps that do not work well with rebar"
make_deps
