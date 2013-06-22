-module (mod_spark_log_chat_srv).
-behaviour(gen_server).
-behaviour(gen_mod).

-export([log_packet_send/3,
	log_packet_receive/4]).

-export([start/2,
	start_link/2,
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
-define(DEFAULT_PATH, ".").
-define(DEFAULT_FORMAT, text).


-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").
-endif.

-include_lib("ejabberd.hrl").
-include_lib("jlib.hrl").

-include_lib("lager/include/lager.hrl").

log_packet_send()->

log_packet_receive()->





start_link(Host, Opts)->
  ?INFO_MSG("Starting ~p Host: ~p Opts: ~p",
		[?SERVER, Host,Opts]),
  Proc = gen_mod:get_module_proc(Host,?PROCNAME),
  gen_server:start_link({local, Proc}, 
		?MODULE, [Host, Opts], []).

start(Host, Opts) ->
    ?DEBUG(" ~p  ~p~n", [Host, Opts]),
    case gen_mod:get_opt(host_config, Opts, []) of
	[] ->
	    start_vh(Host, Opts);
	HostConfig ->
	    start_vhs(Host, HostConfig)
    end.

start_vhs(_, []) ->
    ok;
start_vhs(Host, [{Host, Opts}| Tail]) ->
    ?DEBUG("start_vhs ~p  ~p~n", [Host, [{Host, Opts}| Tail]]),
    start_vh(Host, Opts),
    start_vhs(Host, Tail);
start_vhs(Host, [{_VHost, _Opts}| Tail]) ->
    ?DEBUG("start_vhs ~p  ~p~n", [Host, [{_VHost, _Opts}| Tail]]),
    start_vhs(Host, Tail).
start_vh(Host, Opts) ->
    Path = gen_mod:get_opt(path, Opts, ?DEFAULT_PATH),
    Format = gen_mod:get_opt(format, Opts, ?DEFAULT_FORMAT),
    ejabberd_hooks:add(user_send_packet, Host, ?MODULE, log_packet_send, 55),
    ejabberd_hooks:add(user_receive_packet, Host, ?MODULE, log_packet_receive, 55),
    register(gen_mod:get_module_proc(Host, ?PROCNAME),
	     spawn(?MODULE, init, [#config{path=Path, format=Format}])).


stop(Host) ->
  ?INFO_MSG("~p Stopping Host: ~p",[?SERVER, Host]), 
  ok = ejabberd:delete(user_send_packet, Host,
		?MODULE, log_packet_send, 55),
  ok = ejabberd:delete(user_receive_packet, Host,
		?MODULE, log_packer_receive, 55),
  Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
  gen_server:call(Proc, stop),  
  supervisor:delete_child(ejabberd_sup, Proc).

init([Host, Opts])->
  load_config()

terminate(Reason,State)->
  ?INFO_MSG("~p Stopping Reason: ~p",[?SERVER, Reason]), 
user_receive_packet~p Reason: ~p",[?SERVER, Reason]), 
  
  ok.

code_change(_OldVsn, State, _Extra)->
  {ok, State}.


