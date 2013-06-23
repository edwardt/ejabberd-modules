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
-include_lib("amqp_client/include/amqp_client.hrl").

-record(config, {
		 path		    = ?DEFAULT_PATH, 
		 format		    = ?DEFAULT_FORMAT,
		 username	    = <<"guest">>,
                 password           = <<"guest">>,
                 virtual_host       = <<"/">>,
                 host               = "localhost",
                 port               = undefined,
		 heartbeat          = 0,
		 connection_timeout = infinity,
		 client_properties  = []
}).



log_packet_send(From, To, Packet) ->
    log_packet(From, To, Packet, From#jid.lserver).

log_packet_receive(_JID, From, To, _Packet) 
	when From#jid.lserver =:= To#jid.lserver->
    ok; % self talk
log_packet_receive(_JID, From, To, Packet) ->
    log_packet(From, To, Packet, To#jid.lserver).

log_packet(From, To, Packet = {xmlelement, "message", Attrs, _Els}, Host) ->
    ChatType = xml:get_attr_s("type", Attrs),
    handle_chat_msg(ChatType, From, To, Packet, Host);
log_packet(_From, _To, _Packet, _Host) ->
    ok.



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
	    start_vhost(Host, Opts);
	HostConfig ->
            ?ERROR_MSG("Multiple virtualhost unsupported ~p~n",[HostConfig])
    end.

start_vhost(_Host,[])-> ok;
start_vhost(Host, Opts) ->
    ejabberd_hooks:add(user_send_packet, Host, ?MODULE, log_packet_send, 55),
    ejabberd_hooks:add(user_receive_packet, Host, ?MODULE, log_packet_receive, 55),
    load_config([Host,Opts]).

init()-> init([]).
init([Host,Opts])->
    ?DEBUG("Starting ~p Host: ~p Opt: ~p~n", [?MODULE, Opts]),
    ok = lager:start(),
    Config = start_vhost(Host,Opts),
    {ok, Config}.

stop(Host) ->
  ?INFO_MSG("~p Stopping Host: ~p",[?SERVER, Host]), 
  ok = ejabberd:delete(user_send_packet, Host,
		?MODULE, log_packet_send, 55),
  ok = ejabberd:delete(user_receive_packet, Host,
		?MODULE, log_packer_receive, 55),
  Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
  gen_server:call(Proc, stop),  
  supervisor:delete_child(ejabberd_sup, Proc).


terminate(Reason,_State)->
  ?INFO_MSG("~p Stopped Reason: ~p",[?SERVER, Reason]), 
  ok.

code_change(_OldVsn, State, _Extra)->
  {ok, State}.

%%%%
handle_chat_msg("groupchat", _From, _To, Packet, _Host) ->
    ?DEBUG("dropping groupchat: ~s", [xml:element_to_string(Packet)]),
    ok;   
handle_chat_msg("error", _From, _To, Packet, _Host) ->
    ?DEBUG("dropping error: ~s", [xml:element_to_string(Packet)]),
    ok;   
   
handle_chat_msg(ChatType, From, To, Packet, Host) -> 
    write_packet(ChatType, From, To, Packet, Host).


write_packet(ChatType, From, To, Packet, Host) -> ok.


load_config([])->
   {ok, #config{}};
load_config([Host, Opts])->
   Path = gen_mod:get_opt(path, Opts, ?DEFAULT_PATH),     
   Format = gen_mod:get_opt(format, Opts, ?DEFAULT_FORMAT),
   Username = gen_mod:get_opt(username, Opts, <<"guest">>),
   Password = gen_mod:get_opt(password, Opts, <<"guest">>),
   Virtual_host = gen_mod:get_opt(virtual_host, Opts, <<"/">>),
   Host         = gen_mod:get_opt(host, Opts, Host),
   Port         = gen_mod:get_opt(port, Opts, undefined),
   Heartbeat    = gen_mod:get_opt(heartbeat, Opts, 0),
   Connection_timeout = gen_mod:get_opt(connection_timeout, Opts, infinity),
   Client_properties  = gen_mod:get_opt(client_properties, Opts, []),

   {ok, #config{ path		    = Path, 
		 format		    = Format,
		 username	    = Username,
                 password           = Password,
                 virtual_host       = Virtual_host,
                 host               = Host ,
                 port               = Port,
		 heartbeat          = Heartbeat,
		 connection_timeout = Connection_timeout,
		 client_properties  = Client_properties}}.
