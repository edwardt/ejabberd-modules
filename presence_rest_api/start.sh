#!/bin/sh
cd `dirname $0`
exec erl -pa $PWD/ebin $PWD/deps/*/ebin -boot start_sasl -s reloader -s ejabberd_rest_api \
	-eval "io:format(\"Point your browser at http://localhost:8080/~n\")."