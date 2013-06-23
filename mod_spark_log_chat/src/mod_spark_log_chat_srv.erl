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
-define(PERF, perfcounter).

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
		 idMap		    = [],
		 amqp_params = #amqp_params_direct{}
}).



log_packet_send(From, To, Packet) ->
    %Start_time = app_helper:os_now(),
    lager:log(info,"~p ~p:user_send_message START",[?PERF, ?PROCNAME]), 
    R = log_packet(From, To, Packet, From#jid.lserver),
    %End_time = app_helper:os_now(), 
    lager:log(info,"~p ~p:user_send_message END",[?PERF, ?PROCNAME]), 
    R.

log_packet_receive(_JID, From, To, _Packet) 
	when From#jid.lserver =:= To#jid.lserver->
    ok; % self talk
log_packet_receive(_JID, From, To, Packet) ->
    lager:log(info,"~p ~p:user_receive_message START",[?PERF, ?PROCNAME]),     
    R = log_packet(From, To, Packet, To#jid.lserver),
    lager:log(info,"~p ~p:user_receive_message END",[?PERF, ?PROCNAME]), 
    R.

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


handle_chat_msg(ChatType, From, To, Packet, _Host) -> 
    write_packet(ChatType, From, To, Packet).

write_packet(ChatType, From, To, Packet) -> 
   Proc = gen_mod:get_module_proc(From#jid.server,?PROCNAME),
   gen_server:call(Proc, {push_to_queue, From, To, Packet, ChatType}).


subject(Packet, Format)->
  case xml:get_path_s(Packet, [{elem, "subject"}, cdata]) of
       false -> "";
       Text ->  escape(Format, Text)
  end.

body(Packet, Format)->
   escape(Format, xml:get_path_s(Packet, [{elem, "body"}, cdata])).

from_member(From, IdMap)->
  LUser = jlib:nodeprep(From),  
  app_helper:extract_id_from_jid(LUser, IdMap).

to_member(To)->
  LUser = jlib:nodeprep(To),  
  app_helper:extract_id_from_jid(LUser, IdMap).



handle_call({push_to_queue, From, To, Packet, ChatType}, _From, State)->
  Reply = case is_empty_message(Packet,State#config.format) of
       true -> ?WARNING_MSG("Will not log empty message",[]),
	       empty_message; 
       _ -> post_to_queue(From, To, Packet, ChatType, State)
  end,
  {reply, Reply, State}.

handle_cast(stop, State)->
  {stop,normal, State};

handle_cast(_Request, State)->
  {noreply, State}.

handle_info(timeout,State) ->
  {noreply, State, hibernate};

handle_info(_, State)->
  {noreply, State}.
  

is_empty_message(Packet, Format)->
  Subject = subject(Packet, Format),
  Body = body(Packet, Format),
  equal(Subject,"") and equal(Body, "").

equal(A,B) ->
  A =:= B.

load_config([])->
   {ok, #config{}};
load_config([Host1, Opts])->
   Path = gen_mod:get_opt(path, Opts, ?DEFAULT_PATH),     
   Format = gen_mod:get_opt(format, Opts, ?DEFAULT_FORMAT),
   Username = gen_mod:get_opt(username, Opts, <<"guest">>),
   Password = gen_mod:get_opt(password, Opts, <<"guest">>),
   Virtual_host = gen_mod:get_opt(virtual_host, Opts, <<"/">>),
   Node		= gen_mod:get_opt(node, Opts, node()),
   Adapter_info	= gen_mod:get_opt(adapter_info, Opts, none),
  % Host         = gen_mod:get_opt(host, Opts, Host1),
  % Port         = gen_mod:get_opt(port, Opts, undefined),
  % Heartbeat    = gen_mod:get_opt(heartbeat, Opts, 0),
  % Connection_timeout = gen_mod:get_opt(connection_timeout, Opts, infinity),
   Client_properties  = gen_mod:get_opt(client_properties, Opts, []),

   CfgList = spark_app_config_srv:load_config("ejabberd_auth_spark.config"),
   IdMap = spark_app_config_srv:lookup(community2brandId, CfgList,required), ejabberd_auth_spark_config:spark_communityid_brandid_map(CfgList),
   Amqp_Params = #amqp_params_direct{
		 username	    = Username,
                 password           = Password,
                 virtual_host       = Virtual_host,
                 node              = Node,
                 adapter_info      = Adapter_info,
          %       host               = Host,
          %       port               = Port,
	  %	 heartbeat          = Heartbeat,
	  %	 connection_timeout = Connection_timeout,
          	 client_properties  =
			      Client_properties			

		},
   {ok, #config{ path		    = Path, 
		 format		    = Format,
		 idMap		    = IdMap,
		 amqp_params	    = Amqp_Params}}.

escape(text, Text) ->
    Text;
escape(_, "") ->
    "";
escape(html, [$< | Text]) ->
    "&lt;" ++ escape(html, Text);
escape(html, [$& | Text]) ->
    "&amp;" ++ escape(html, Text);
escape(html, [Char | Text]) ->
    [Char | escape(html, Text)].


