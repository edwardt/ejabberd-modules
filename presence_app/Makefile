

all: compile

depends:
	./rebar -vvv get-deps
	./rebar -vvv update-deps

compile:
	./rebar -vvv compile

generate:
	./copy_all_deps_ebeam.sh
	\rm -f ebeam.tar.gz
	\rm -rf ejabberd_auth_spark_v_10
	tar -cvf ebeam.tar.gz ./ebeam
	tar -cvf conf.tar.gz ./conf


clean:
	./rebar clean



.PHONY: all depends compile
