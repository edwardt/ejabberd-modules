%%%----------------------------------------------------------------------
%%% File    : mod_spark_log_chat.erl
%%% Author  : 
%%% Purpose : Log 2 ways chat messages & publish to rabbitmq
%%% Id      : $Id$
%%%----------------------------------------------------------------------

-module(mod_spark_log_chat).
-author('etsang@spark.net').

-behaviour(gen_mod).
-behaviour(gen_server).

-export([start/2,
         init/1,
	 stop/1, test/0,
	 log_packet_send/3,
	 log_packet_receive/4]).

-export([start_link/1, start_link/2]).
-export([
	  handle_call/3,
		 handle_cast/2,
		 handle_info/2, 
		 terminate/2, 
		 code_change/3]).

%-define(ejabberd_debug, true).

-include("ejabberd.hrl").
-include("jlib.hrl").
-include_lib("chat_message.hrl").

-define(PROCNAME, ?MODULE).
-define(DEFAULT_PATH, ".").
-define(DEFAULT_FORMAT, text).
-define(ConfPath,"conf").
-define(ConfFile, "spark_amqp.config").
-define(TableName, id_map).
-define(PUBMOD, 'spark_rabbit_publisher').
-define(FUNC, publish).
-define(TIMEOUT, 2000).

-record(state, {
	publisher = [],
	idMap =[],
	format = ?DEFAULT_FORMAT
}).


-type state() :: #state{}.
-type chat_message() :: #chat_message{}.
-type jid() :: #jid{}.
-type xmlelement() :: string(). % TODO just say string for now.
-type datatimefmt() :: calendar:datetime1970().

start_link([Host, Opts]) -> start_link(Host, Opts).
-spec start_link(string(), list()) ->ok | {error, term()}.
start_link(Host, Opts)->
  ?INFO_MSG("~p gen_server starting  ~p ~p~n", [?PROCNAME, Host, Opts]),
  Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
  ensure_dependency_started(Proc),
  gen_server:start_link({local, Proc}, ?MODULE, [Host, Opts],[]).

ensure_dependency_started(Proc)->
  ?INFO_MSG("[~p] Starting depedenecies", [Proc]),
  Apps = [syntax_tools, 
		compiler, 
		crypto,
		public_key,
	   % gen_server2,
		ssl, 
		%ets,
		goldrush, 
		rabbit_common,
		amqp_client,
		inets, 
		restc],
  ?INFO_MSG("[~p] Going to start apps ~p", [Proc, lists:flatten(Apps)]),
  app_util:start_apps(Apps),
  %ok = lager:start(),
  ?INFO_MSG("[~p] Started depedenecies ~p", [Proc, lists:flatten(Apps)]).


-spec start(string(), list()) -> ok | {error, term()}.
start(Host, Opts) ->
    ?INFO_MSG(" ~p  ~p~n", [Host, Opts]),
  %   start_amqp(Host, Opts),
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    ChildSpec = {Proc,
       {?MODULE, start_link, [Host, Opts]},
       temporary,
       1000,
       worker,
       [?MODULE]},
   
    supervisor:start_child(ejabberd_sup, ChildSpec).

start_amqp(Host, Opts)->
      Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
   	ChildSpec = {Proc,
       {spark_amqp_session, start_link, [Host, Opts]},
       temporary,
       1000,
       worker,
       [?MODULE]},

       supervisor:start_child(ejabberd_sup, ChildSpec).	

-spec start_vhs(string(), list()) -> ok | [{atom(), any()}].
start_vhs(_, []) ->
    ok;
start_vhs(Host, [{Host, Opts}| Tail]) ->
    ?INFO_MSG("start_vhs ~p  ~p~n", [Host, [{Host, Opts}| Tail]]),
    start_vh(Host, Opts),
    start_vhs(Host, Tail);
start_vhs(Host, [{_VHost, _Opts}| Tail]) ->
    ?INFO_MSG("start_vhs ~p  ~p~n", [Host, [{_VHost, _Opts}| Tail]]),
    start_vhs(Host, Tail).
start_vh(Host, Opts) ->
    Publisher = gen_mod:get_opt(publisher, Opts, ?DEFAULT_FORMAT),
    Format = gen_mod:get_opt(format, Opts, ?DEFAULT_FORMAT),
    IdMap = gen_mod:get_opt(idMap, Opts, []), 
    ejabberd_hooks:add(user_send_packet, Host, ?MODULE, log_packet_send, 55),
    ejabberd_hooks:add(user_receive_packet, Host, ?MODULE, log_packet_receive, 55),
    ok = is_reachable(Publisher),
    #state{
	    publisher = Publisher,
        format = Format,
   	    idMap = IdMap
    	}.

is_reachable([]) -> ok;
is_reachable([H|T]) ->
  {ok, reachable} = is_node_reachable(H),  	
  is_reachable(T).

is_node_reachable('pong') -> {ok, reachable}; 
is_node_reachable('pang') -> {error, unreachable};
is_node_reachable(Name) when is_atom(Name) ->
   error_logger:info_msg("Going to ping node ~p",[Name]),
   is_node_reachable(net_adm:ping(Name)).  

lookup_brandid(Jid, IdMap)->
   UserName = jlib:jid_to_string(Jid),
   lookup_brandid_from_user(id_map, UserName, IdMap). 

lookup_brandid_from_user(Name, UserName, IdMap) when is_atom(Name) ->
   [MemberId, CommunityId] = split_composite_id(UserName),
   C = case list:keyfind(CommunityId, 1 , IdMap ) of
   		false -> [];
   	    { _, _, B} -> B
   end,
   ?INFO_MSG("Found BrandId ~p", [C]),
   C. 

split_composite_id(UserName) when is_binary(UserName) ->
  UserNameStr = binary_to_list(UserName),
  case split_composite_id(UserNameStr) of
  		[A,B] -> [list_to_binary(A), list_to_binary(B)];
  		Else -> [<<"">>,<<"">>]
  end;
  
split_composite_id(UserName) when is_list(UserName)-> 
   case re:split(UserName,"-")	of
	[MemberId, CommunityId]->  [MemberId, CommunityId];
	[] -> [UserName, ""];	
	R -> [R, ""]
   end.


-spec init([any()]) -> {ok, pid()} | {error, tuple()}.
init([Host, Opts])->
    ?INFO_MSG("Starting Module ~p PROCNAME ~p with host ~p config ~p~n", [?MODULE, ?PROCNAME, Host, Opts]),
    R = case gen_mod:get_opt(host_config, Opts, []) of
		[] ->
		    start_vh(Host, Opts);
		_HostConfig ->
			?ERROR_MSG("Multiple virtual host unsupported",[]),
			#state{}
%	 	    start_vhs(Host, HostConfig)
   	end,
    {ok, R}.

-spec stop(string()) -> ok.
stop(Host) ->
    ejabberd_hooks:delete(user_send_packet, Host,
			  ?MODULE, log_packet_send, 55),
    ejabberd_hooks:delete(user_receive_packet, Host,
			  ?MODULE, log_packet_receive, 55),
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    gen_server:call(Proc, stop),
    supervisor:delete_child(ejabberd_sup, Proc),
    ok.

-spec test()-> {ok, state()}.
test()->
    gen_server:call(?PROCNAME, ping).

-spec log_packet_send(jid(), jid(),xmlelement()) -> ok | {error, term()}.
log_packet_send(From, To, Packet) ->
    log_packet(From, To, Packet, From#jid.lserver).

-spec log_packet_receive(jid(), jid(), jid(),xmlelement()) -> ok | {error, term()}.
log_packet_receive(_JID, From, To, _Packet) 
	when From#jid.lserver =:= To#jid.lserver->
    ok; % self talk
log_packet_receive(_Jid, From, To, Packet) -> 
    log_packet(From, To, Packet, To#jid.lserver).

-spec log_packet(jid(), jid(), xmlelement(), string())-> ok | {error, term()}.
log_packet(From, To, Packet = {xmlelement, "message", Attrs, _Els}, Host) ->
    ChatType = xml:get_attr_s("type", Attrs),
    FromJid = get_jid(From),
    ToJid = get_jid(To),
        
    handle_chat_msg(ChatType, FromJid, ToJid, Packet, Host);
log_packet(_From, _To, _Packet, _Host) ->
    ok.
-spec handle_chat_msg(atom(),jid(), jid(), xmlelement(), string()) -> ok | {error, term()}.
handle_chat_msg("groupchat", _From, _To, Packet, _Host) ->
    ?INFO_MSG("dropping groupchat: ~s", [xml:element_to_string(Packet)]),
    ok;   
handle_chat_msg("error", _From, _To, Packet, _Host) ->
    ?INFO_MSG("dropping error: ~s", [xml:element_to_string(Packet)]),
    ok;   
   
handle_chat_msg(ChatType, FromJid, ToJid, Packet, Host) -> 
    ?INFO_MSG("Writing packet to ~p rabbitmq: ", [?PROCNAME]),
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    gen_server:call(Proc, {write_packet, ChatType, FromJid, ToJid, Packet, Host}).

-spec handle_call(tuple(), pid(), state()) -> {reply, any(), state()}.
handle_call({write_packet, Type, FromJid, ToJid, Packet, Host}, _From, State) ->
  Start = os_now(),
  IdMap = State#state.idMap,
  ?INFO_MSG("Start publish message to rabbitmq: start ~p ", [Start]),
  Node = get_publisher_node(State),
  Reply = write_packet(Type, FromJid, ToJid, Packet, Host, IdMap, Node),
  End = os_now(),
  ?INFO_MSG("Published packet to rabbitmq: start ~p end ~p", [Start, End]),
  {reply, Reply, State};

handle_call(ping, _From, State) ->
  {reply, {ok, State}, State};

handle_call(stop, _From, State) ->
  {stop, normal, stopped, State};

handle_call(_Request, _From, State) ->
    Reply = {error, function_clause},
    {reply, Reply, State}.

-spec handle_cast(tuple(), state()) -> {noreply, state()}.
handle_cast(Info, State) ->
	erlang:display(Info),
    {noreply, State}.

-spec handle_info(tuple(), state()) -> {ok, state()}.
handle_info(_Info, State) ->
  {ok, State}.

-spec handle_info(tuple(), pid(), state()) -> {ok, state()}.
handle_info(stop, _From, State)->
  terminate(normal, State).

-spec terminate(atom(), state()) -> ok.
terminate(Reason, _State) ->
  ?INFO_MSG("~p has been terminated ~p ", [?PROCNAME, Reason]),
  ok.

-spec code_change(atom, state(), list()) -> ok.
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

-spec write_packet(jid(), jid(), string(), string(), string(),[tuple()], atom()) -> ok | {error, term()}.  
write_packet(Type, FromJid, ToJid, Packet, _Host, IdMap, Node) ->
    Format = get_im_transform_format(Type),
    Subject = get_subject(Format, Packet),
    Body = get_body(Format, Packet),
   % Thread = get_thread(User, Server, Resource, Format, Packet),
 	Thread = get_thread(FromJid), 
    ?INFO_MSG("Type ~p Extracted Subject ~p Body ~p Thread ~p",[Type, Subject, Body, Thread]),
    case <<Subject/binary,Body/binary>> of
        <<>> -> %% don't log empty messages
            ?INFO_MSG("not logging empty message from ~s",[jlib:jid_to_string(FromJid)]),
            ok;
        _ ->
        	MessageItem = parse_message(FromJid, ToJid, Type, Subject, Body, Thread, IdMap), 
        	?INFO_MSG("Will publish Message Payload ~p ", [MessageItem]),
        	post_to_rabbitmq(MessageItem, Node)
    end.
 
get_user_from_jid(From)->
    From#jid.user.

-spec parse_message(jid(), jid(), atom(), string(), string(), string(), [tuple()]) -> chat_message().
parse_message(FromJid, ToJid, Type, Subject, Body, Thread, IdMap)->
  
   User = get_user_from_jid(FromJid),
   [From, _] = split_composite_id(User),
%   FromBrandId = lookup_brandid(User),
   FromBrandId = lookup_brandid_from_user(?TableName, User, IdMap),
%get_memberId(FromJid, IdMap),
   UserB = get_user_from_jid(ToJid),
   [To, _] = split_composite_id(UserB),
%   ToBrandId= lookup_brandid(UserB),
   ToBrandId = lookup_brandid_from_user(?TableName, UserB, IdMap),
%get_memberId(ToJid, IdMap),
    Format = ?DEFAULT_FORMAT,
    %TimeStamp = app_util:get_printable_timestamp(),
    TimeStamp  = os:timestamp(),
	TimeStamp0 = iso8601:format(TimeStamp),
    #chat_message{
    	from = ensure_binary(From),
		to = ensure_binary(To),
    	brandId = ensure_binary(ToBrandId),
    	type = ensure_binary(Type),
    	format = ensure_binary(Format),
    	subject = ensure_binary(Subject),
    	body = ensure_binary(Body),
    	thread = ensure_binary(Thread),
    	time_stamp = ensure_binary(TimeStamp0)
    }.

-spec get_memberId(jid(), [tuple()]) ->[string()].
get_memberId(Jid, IdMap)->
    lookup_brandid(Jid,IdMap).
%   UserName = jlib:jid_to_string(Jid),
%   [MemberId, BrandId] = get_login_data(UserName, IdMap),
%   [MemberId, BrandId].

-spec get_im_transform_format(any())->atom().
get_im_transform_format(_)->
   ?DEFAULT_FORMAT.

-spec post_to_rabbitmq(chat_message(), atom())-> ok | {error, term()}.
post_to_rabbitmq(#chat_message{} = MessageItem, Node) ->
	Payload = ensure_binary(MessageItem),
	rpc:async_call(Node, ?PUBMOD, ?FUNC, [MessageItem]).
	%mod_spark_rabbitmq:publish(call, chat_message_model, Payload).


publish_cast(Node, MessageItem) ->
	rpc:async_call(Node, ?PUBMOD, ?FUNC, [MessageItem]).

publish_call(Node, MessageItem) ->
	rpc:call(Node, ?PUBMOD, ?FUNC, [MessageItem], ?TIMEOUT).

get_publisher_node(State)->
	Nodes = State#state.publisher,
	Length = length(Nodes),
	Index = random:uniform(Length),
	lists:nth(Index, Nodes).

-spec get_subject(atom, xmlelement())-> string().
get_subject(Format, Packet) ->
	R = parse_body(Format, xml:get_path_s(Packet, [{elem, "subject"}, cdata])),
  ensure_binary(R).

-spec get_body(atom, xmlelement())-> string().
get_body(Format, Packet) ->
  R = parse_body(Format, xml:get_path_s(Packet, [{elem, "body"}, cdata])),
  ensure_binary(R).

%-spec get_thread(atom, xmlelement())-> string().
get_thread(Format, Packet) ->
  R = parse_body(Format, xml:get_path_s(Packet, [{elem, "thread"}, cdata])),
  ensure_binary(R).
%-spec get_thread(tuple())-> string().
get_thread(Jid) ->
  {User, Server, Resource} = spark_jid:get_usr(Jid),
  R = ejabberd_sm:get_session_pid(User, Server, Resource), 
  ensure_binary(R).

  
  
-spec get_jid(string()) -> string().
get_jid(Jid) ->
  case spark_jid:split_jid(Jid) of 
  		[_, RealJid, _,CommunityId] -> 
  			spark_jid:reconstruct_spark_jid(RealJid, CommunityId);
  		[RealJid,_,CommunityId] -> 
  		    spark_jid:reconstruct_spark_jid(RealJid, CommunityId);
  		[A,B] -> [A,B];
  		Else -> Else  
  end.

-spec parse_body(atom, false|xmlelement())->string().
parse_body(_Format, false) -> "";
parse_body(Format, Text) -> escape(Format, Text).

-spec escape(atom, xmlelement()) -> string().
escape(text, Text) -> Text;
escape(_, "") -> "";
escape(html, [$< | Text]) ->
	lists:concat(["&lt;", escape(html, Text)]);
%    "&lt;" ++ escape(html, Text);
escape(html, [$& | Text]) ->
	lists:concat(["&amp;" , escape(html, Text)]);
%    "&amp;" ++ escape(html, Text);
escape(html, [Char | Text]) ->
    [Char | escape(html, Text)].

-spec get_memberId_communityId(jid()) -> [].
get_memberId_communityId([])-> [];
get_memberId_communityId(UserName) ->
  case re:split(UserName,"-") of 
      [MemberId, CommunityId] -> [MemberId, CommunityId];
              {error, Reason} -> {error, Reason};
              Else -> {error, Else}
  end.

-spec get_login_data(jid(), string()) -> [jid()].
get_login_data(_,[])-> ["",""];
get_login_data(UserName, IdMap) ->
  [MemberId, CommunityId] = get_memberId_communityId(UserName), 
  BrandIdStr = find_value(CommunityId, IdMap),
  [erlang:binary_to_list(MemberId), BrandIdStr]. 

find_value(Key, List) ->
  Key1 = erlang:binary_to_list(Key),
  case lists:keyfind(Key1, 2, List) of
        {_Type, _Key, Result} -> Result;
        false -> {error, not_found};
        {error, Reason} -> {error, Reason}
  end.

-spec ensure_binary(atom | any()) -> binary().
ensure_binary(#chat_message{} = Value) ->
	Json = json_rec:to_json(Value, chat_message_model),
  ?INFO_MSG("Chat Message as Json ~p",[Json]),
  lists:flatten(mochijson2:encode(Json));

ensure_binary(Value) -> app_util:ensure_binary(Value).

-spec os_now() -> calendar:datetime1970().
os_now()-> app_util:get_printable_timestamp().


