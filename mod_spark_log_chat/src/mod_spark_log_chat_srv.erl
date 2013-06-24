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
-define(DEFAULT_NAME,<<"dev">>).
-define(DEFAULT_EXCHANGE, <<"conversation">>).
-define(DEFAULT_QUEUE, <<"post_to_api">>).
-define(PERF, perfcounter).
-define(HIBERNATE_TIMEOUT, 90000).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").
-endif.

-include_lib("ejabberd.hrl").
-include_lib("jlib.hrl").
-include_lib("mod_spark_log_chat.hrl").

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
    {ok, Channel} = amqp_channel(Config#config.amqp_params),
    declare_exchange(Channel, Config#config.exchange, Config#config.queue),
    {ok, Config}.

declare_exchange(Channel, Exchange, Queue)->
    #'exchange.declare_ok'{} = amqp_channel:call(Channel,   #'exchange.declare'{exchange = Exchange, type = <<"topic">> }),
    #'queue.declare_ok'{} = amqp_channel:call(Channel,
#'queue.declare'{queue = Queue}).

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


get_subject(Packet, Format)->
  case xml:get_path_s(Packet, [{elem, "subject"}, cdata]) of
       false -> "";
       Text ->  escape(Format, Text)
  end.

get_body(Packet, Format)->
   escape(Format, xml:get_path_s(Packet, [{elem, "body"}, cdata])).

from_member(From, IdMap)->
  LUser = jlib:nodeprep(From),  
  app_helper:extract_id_from_jid(LUser, IdMap).

to_member(To, IdMap)->
  LUser = jlib:nodeprep(To),  
  app_helper:extract_id_from_jid(LUser, IdMap).


handle_call({push_to_queue, From, To, Packet, ChatType}, _From, State)->
  Reply = case is_empty_message(Packet, State#config.format) of
       true -> ?WARNING_MSG("Will not log empty message",[]),
	       empty_message; 
       _ -> Date = erlang:date(),
	    Time = erlang:now(),
            post_to_queue(Date, Time, From, To, Packet, ChatType, 
	        State) 
  end,
  {reply, Reply, State, State#config.connection_timeout};

handle_call({get_from_queue}, _From, State)->
  Reply = get_from_queue(State),
  {reply, Reply, State};

handle_call({post_to_api, Message}, _From, State)->
  Reply = post_to_api(Message, State),  
  
  {reply, Reply, State, State#config.connection_timeout};

handle_call({#'basic.consume_ok'{}}, From, State)-> 
  Reply = gen_server:info({#'basic.consume_ok'{}}, From, State),
  {reply, Reply, State};
handle_call({#'basic.cancel_ok'{}}, From, State)->
  Reply = gen_server:info({#'basic.cancel_ok'{}}, From,State),
  {reply, Reply, State};
handle_call({#'basic.deliver'{}}, From, State)->
  Reply = gen_server:info({#'basic.deliver'{}},From ,State),
  {reply, Reply, State}.

handle_cast(stop, State)->
  {stop,normal, State};

handle_cast(_Request, State)->
  {noreply, State}.

handle_info(timeout,State) ->
  {noreply, State, hibernate}.

handle_info({#'basic.consume_ok'{}}, _From, State)->   
  {noreply, State};
handle_info({#'basic.cancel_ok'{}}, _From, State)->
  {noreply, State};
handle_info({#'basic.deliver'{delivery_tag=Tag},Content}, _From, State)->
  gen_server:call({post_to_api, Content}, State),
  {noreply, State}.
 

is_empty_message(Packet, Format)->
  Subject = get_subject(Packet, Format),
  Body = get_body(Packet, Format),
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
   Env_Name = gen_mod:get_opt(envionment_name, Opts, ?DEFAULT_NAME),
   Exchange = gen_mod:get_opt(exchange, Opts, ?DEFAULT_EXCHANGE),
   Queue = gen_mod:get_opt(queue, Opts, ?DEFAULT_QUEUE),
%   Node		= gen_mod:get_opt(node, Opts, node()),
%   Adapter_info	= gen_mod:get_opt(adapter_info, Opts, none),
   Host         = gen_mod:get_opt(host, Opts, Host1),
   Port         = gen_mod:get_opt(port, Opts, undefined),
   Heartbeat    = gen_mod:get_opt(heartbeat, Opts, 0),
   Connection_timeout = gen_mod:get_opt(connection_timeout, Opts, ?HIBERNATE_TIMEOUT),
   Client_properties  = gen_mod:get_opt(client_properties, Opts, []),

   CfgList = spark_app_config_srv:load_config("ejabberd_auth_spark.config"),
   IdMap = spark_app_config_srv:lookup(community2brandId, CfgList,required), ejabberd_auth_spark_config:spark_communityid_brandid_map(CfgList),
   Amqp_Params = #amqp_params_network{
		 username	    = Username,
                 password           = Password,
                 virtual_host       = Virtual_host,
	 	 
          %       node              = Node,
          %       adapter_info      = Adapter_info,
                 host               = Host,
                 port               = Port,
	  	 heartbeat          = Heartbeat,
	  	 connection_timeout = Connection_timeout,
          	 client_properties  =
			      Client_properties			

		},
   {ok, #config{ path		    = Path, 
		 format		    = Format,
		 idMap		    = IdMap,
		 host 		    = Host1,
		 name 		    = Env_Name,
		 exchange 	    = Exchange,
		 queue 		    = Queue,
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

%%%  ********************************************************
post_to_queue(Date, Time, From, To, Packet, ChatType, 
	     #config{amqp_params = AmqpParams } = State) ->
  case amqp_channel(AmqpParams) of
    {ok, Channel} ->
      Message = transform_chat_msg(From, To, Packet, ChatType, State),
      send(State,[Date, " ", Time, " ", Message], Channel, ChatType);
    _ ->
      State
  end.


transform_chat_msg(From, To, Packet, _ChatType, State)-> 
  Sid = get_session_id(From, State#config.host,[]),   
  Format = State#config.format,
  IdMap = State#config.idMap,
  [From_Mid, From_Bid] = from_member(From, IdMap),  
  [To_Mid, To_Bid] = to_member(To, IdMap),    
  #chat_msg{
	sid = Sid,
	subject = get_subject(Packet,Format),
        from_mid = From_Mid,
	from_bid = From_Bid,
	to_mid = To_Mid,
	to_bid = To_Bid,
	body = get_body(Packet,Format)
  }. 

get_session_id(User, Server, Resource)->
   ejabberd_sm:get_session_pid(User, Server, Resource).

send(#config{ name = Name, exchange = Exchange, queue = Queue} = State, Message, Channel, ChatType) ->
  RkPrefix = atom_to_list(ChatType),
  RoutingKey =  list_to_binary( case Name of
                                  [] ->
                                    RkPrefix;
                                  Name ->
                                    string:join([RkPrefix, Name], ".")
                                end
                              ),
   
  Publish = #'queue.bind'{queue= Queue, exchange = Exchange, routing_key = RoutingKey },
  Props = #'P_basic'{ content_type = <<"text/plain">> },
  Body = list_to_binary(lists:flatten(Message)),
  Msg = #amqp_msg{ payload = Body, props = Props },

  % io:format("message: ~p~n", [Msg]),
  amqp_channel:cast(Channel, Publish, Msg),
  State.


get_from_queue(#config{amqp_params = AmqpParams, exchange = Exchange,queue = Queue } = State) ->
  R = case amqp_channel(AmqpParams) of
    {ok, Channel} ->
      #'basic.consume_ok'{consumer_tag = Tag} = amqp_channel:subscribe(Channel, #'basic.consume'{queue=Queue}, self());
       _ ->
      State
  end,
  R.



amqp_channel(AmqpParams) ->
  case maybe_new_pid({AmqpParams, connection},
                     fun() -> amqp_connection:start(AmqpParams) end) of
    {ok, Client} ->
      maybe_new_pid({AmqpParams, channel},
                    fun() -> amqp_connection:open_channel(Client) end);
    Error ->
      Error
  end.

maybe_new_pid(Group, StartFun) ->
  case pg2:get_closest_pid(Group) of
    {error, {no_such_group, _}} ->
      pg2:create(Group),
      maybe_new_pid(Group, StartFun);
    {error, {no_process, _}} ->
      case StartFun() of
        {ok, Pid} ->
          pg2:join(Group, Pid),
          {ok, Pid};
        Error ->
          Error
      end;
    Pid ->
      {ok, Pid}
  end.

post_to_api(Message, State)->

  io:format("sending to service api",[]),
  ok.
