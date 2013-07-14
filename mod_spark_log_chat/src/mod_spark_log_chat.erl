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
	 	 stop/1, ping/0,
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

-record(state, {
	idMap =[],
	format = ?DEFAULT_FORMAT
}).


-type state() :: #state{}.
-type chat_message() :: #chat_message{}.
-type jid() :: #jid{}.
-type xmlelement() :: string(). % TODO just say string for now.

start_link([Host, Opts]) -> start_link(Host, Opts).
-spec start_link(string(), list()) ->ok | {error, term()}.
start_link(Host, Opts)->
	?INFO_MSG("~p gen_server starting  ~p ~p~n", [?PROCNAME, Host, Opts]),
	Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
%	R0 = gen_server:start_link({local, rabbit_farms}, ?MODULE, [], []),
	R1 = gen_server:start_link({local, Proc}, ?MODULE, [Host, Opts],[]),
  ?INFO_MSG("gen_server started mod_spark_log_chat ~p~n", [R1]),
%  R0 = gen_server:start_link({local, rabbit_farms}, rabbit_farms, [], []),
%  ?INFO_MSG("gen_server started rabbit_farms ~p", [R0]),
  R1.

-spec start(string(), list()) -> ok | {error, term()}.
start(Host, Opts) ->
    ?INFO_MSG(" ~p  ~p~n", [Host, Opts]),
   	Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
   	ChildSpec = {Proc,
       {?MODULE, start_link, [Host, Opts]},
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
    Format = gen_mod:get_opt(format, Opts, ?DEFAULT_FORMAT),
    IdMap = gen_mod:get_opt(idMap, Opts, []),
    ejabberd_hooks:add(user_send_packet, Host, ?MODULE, log_packet_send, 55),
    ejabberd_hooks:add(user_receive_packet, Host, ?MODULE, log_packet_receive, 55),
    %?INFO_MSG(" Format ~p  IdMap ~p~n", [Format, IdMap]),
    #state{
        format = Format,
   	    idMap = IdMap
    	}.

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

-spec ping()-> {ok, state()}.
ping()->
	gen_server:call(?PROCNAME, ping).

-spec log_packet_send(jid(), jid(),xmlelement()) -> ok | {error, term()}.
log_packet_send(From, To, Packet) ->
    log_packet(From, To, Packet, From#jid.lserver).

-spec log_packet_receive(jid(), jid(), jid(),xmlelement()) -> ok | {error, term()}.
log_packet_receive(_JID, From, To, _Packet) 
	when From#jid.lserver =:= To#jid.lserver->
    ok; % self talk
log_packet_receive(_JID, From, To, Packet) -> 
    log_packet(From, To, Packet, To#jid.lserver).

-spec log_packet(jid(), jid(), xmlelement(), string())-> ok | {error, term()}.
log_packet(From, To, Packet = {xmlelement, "message", Attrs, _Els}, Host) ->
    ChatType = xml:get_attr_s("type", Attrs),
    handle_chat_msg(ChatType, From, To, Packet, Host);
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
%     write_packet(ChatType, FromJid, ToJid, Packet, Host, []).
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    gen_server:call(Proc, {write_packet, ChatType, FromJid, ToJid, Packet, Host}).
%    write_packet(From, To, Packet, Host).

-spec handle_call(tuple(), pid(), state()) -> {reply, any(), state()}.
handle_call({write_packet, Type, FromJid, ToJid, Packet, Host}, _From, State) ->
  Start = os_now(),
  IdMap = State#state.idMap,
  ?INFO_MSG("Start publish message to rabbitmq: start ~p ", [Start]),
  Reply = write_packet(Type, FromJid, ToJid, Packet, Host, IdMap),
  End = os_now(),
  ?INFO_MSG("Published packet to rabbitmq: start ~p end ~p time span ~p", [Start, End, timespan(Start, End)]),
  {reply, Reply, State};

handle_call(ping, _From, State) ->
  {reply, {ok, State}, State};
handle_call(stop, _From, State) ->
  {stop, normal, State};
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

-spec write_packet(jid(), jid(), string(), string(), string(),[tuple()]) -> ok | {error, term()}.  
write_packet(Type, FromJid, ToJid, Packet, _Host, IdMap) ->
    Format = get_im_transform_format(Type),
    Subject = get_subject(Format, Packet),
    Body = get_body(Format, Packet),
    Thread = get_thread(Format, Packet),
    ?INFO_MSG("Type ~p Extracted Subject ~p Body ~p Thread ~p",[Type, Subject, Body, Thread]),
    case <<Subject/binary,Body/binary>> of
        <<>> -> %% don't log empty messages
            ?INFO_MSG("not logging empty message from ~s",[jlib:jid_to_string(FromJid)]),
            ok;
        _ ->
        	MessageItem = parse_message(FromJid, ToJid, Type, Subject, Body, Thread, IdMap), 
        	?INFO_MSG("Will publish Message Payload ~p ", [MessageItem]),
        	post_to_rabbitmq(MessageItem)
    end.

-spec parse_message(jid(), jid(), atom(), string(), string(), string(), [tuple()]) -> chat_message().
parse_message(FromJid, ToJid, Type, Subject, Body, Thread, IdMap)->
	[From, FromBrandId] = get_memberId(FromJid, IdMap),
	[To, ToBrandId]= get_memberId(ToJid, IdMap),
    Format = ?DEFAULT_FORMAT,
    TimeStamp = get_timestamp(),
    #chat_message{
    	from = From,
	 	from_brandId = FromBrandId,
    	to = To,
    	to_brandId = ToBrandId,
    	type = Type,
    	format = Format,
    	subject = Subject,
    	body = Body,
    	thread = Thread,
    	time_stamp = TimeStamp
    }.

-spec get_memberId(jid(), [tuple()]) ->[string()].
get_memberId(Jid, IdMap)->
   UserName = jlib:jid_to_string(Jid),
   [MemberId, BrandId] = get_login_data(UserName, IdMap),
   [MemberId, BrandId].

-spec get_im_transform_format(any())->atom().
get_im_transform_format(_)->
   ?DEFAULT_FORMAT.

-spec post_to_rabbitmq(chat_message())-> ok | {error, term()}.
post_to_rabbitmq(#chat_message{} = MessageItem) ->
	Payload = ensure_binary(MessageItem),
	rabbit_farms:publish(call, Payload).

-spec get_subject(atom, xmlelement())-> string().
get_subject(Format, Packet) ->
	R = parse_body(Format, xml:get_path_s(Packet, [{elem, "subject"}, cdata])),
  ensure_binary(R).

-spec get_body(atom, xmlelement())-> string().
get_body(Format, Packet) ->
  R = parse_body(Format, xml:get_path_s(Packet, [{elem, "body"}, cdata])),
  ensure_binary(R).

-spec get_thread(atom, xmlelement())-> string().
get_thread(Format, Packet) ->
  R = parse_body(Format, xml:get_path_s(Packet, [{elem, "thread"}, cdata])),
  ensure_binary(R).
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
-spec get_timestamp() -> calendar:datetime1970().
get_timestamp() ->
  {A,B} =os_now(),
  O = tuple_to_list(A),
  P = tuple_to_list(B),
  mongreljson:tuple_to_json({date_time, lists:concat([O,P])}).

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
ensure_binary(undefined)->
	undefined;
ensure_binary(#chat_message{} = Value) ->
	Json = json_rec:to_json(Value, chat_message_model),
  ?INFO_MSG("Chat Message as Json ~p",[Json]),
	R = lists:flatten(mochijson2:encode(Json)),
  R;

ensure_binary(Value) when is_binary(Value)->
	Value;
ensure_binary(Value) when is_list(Value)->
	list_to_binary(Value).

-spec os_now() -> calendar:datetime1970().
os_now()->
  R =os:timestamp(),
  calendar:now_to_universal_time(R).

-spec timespan( calendar:datetime1970(), calendar:datetime1970())-> calendar:datetime1970().
timespan(A,B)->
  calendar:time_difference(A,B).
	
