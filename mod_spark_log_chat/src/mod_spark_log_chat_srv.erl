-module (mod_spark_log_chat_srv).
-behaviour(gen_server).
-behaviour(gen_mod).

-export([log_packet_send/3,
	log_packet_receive/4]).

-export([start/2,
	init/0,
	init/1,
	stop/1]).

-export([
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").
-endif.

-include_lib("ejabberd.hrl").
-include_lib("jlib.hrl").

-include_lib("lager/include/lager.hrl").

