-module(mod_spark_rabbitmq).
-author(etsang@spark.net).

-behaviour(gen_mod).
-behaviour(gen_server).

-export([log_packet_send/3,
	log_packet_receive/4]).

-export([start/2,
	start_link/2, 
	start_link/3,
	stop/1]).

-export([
 	init/0,
	init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).

-define(SERVER, mod_spark_log_chat).
-define(PROCNAME, ?MODULE).



