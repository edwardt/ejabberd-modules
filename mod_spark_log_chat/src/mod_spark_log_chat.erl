%%%----------------------------------------------------------------------
%%% File    : mod_spark_log_chat.erl
%%% Author  : 
%%% Purpose : Log 2 ways chat messages & publish to rabbitmq
%%% Id      : $Id$
%%%----------------------------------------------------------------------

-module(mod_spark_log_chat).
-author('etsang@spark.net').

-behaviour(gen_mod).

-export([start/2,
         init/1,
	 	 stop/1,
	 	 log_packet_send/3,
	 	 log_packet_receive/4]).

%-define(ejabberd_debug, true).

-include("ejabberd.hrl").
-include("jlib.hrl").

-define(PROCNAME, ?MODULE).
-define(DEFAULT_PATH, ".").
-define(DEFAULT_FORMAT, text).

-record(config, {path=?DEFAULT_PATH, format=?DEFAULT_FORMAT}).

-record(message, {
		from,
		from_brandId,
		to,
		to_brandId,
		type, 
		subject, 
		body, 
		thread,
		time_stamp}).

-record(state, {
	idMap =[]

}).

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
    IdMap = gen_mod:get_opt(idMap, Opts, []),
    ejabberd_hooks:add(user_send_packet, Host, ?MODULE, log_packet_send, 55),
    ejabberd_hooks:add(user_receive_packet, Host, ?MODULE, log_packet_receive, 55),
    
    register(gen_mod:get_module_proc(Host, ?PROCNAME),
	     spawn(?MODULE, init, [#config{path=Path, format=Format}])).

init(Config)->
    ?DEBUG("Starting ~p with config ~p~n", [?MODULE, Config]),
    ok.

stop(Host) ->
    ejabberd_hooks:delete(user_send_packet, Host,
			  ?MODULE, log_packet_send, 55),
    ejabberd_hooks:delete(user_receive_packet, Host,
			  ?MODULE, log_packet_receive, 55),
    gen_mod:get_module_proc(Host, ?PROCNAME) ! stop,
    ok.

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

handle_chat_msg("groupchat", _From, _To, Packet, _Host) ->
    ?DEBUG("dropping groupchat: ~s", [xml:element_to_string(Packet)]),
    ok;   
handle_chat_msg("error", _From, _To, Packet, _Host) ->
    ?DEBUG("dropping error: ~s", [xml:element_to_string(Packet)]),
    ok;   
   
handle_chat_msg(ChatType, From, To, Packet, Host) -> 
    write_packet(From, To, Packet, Host).
   
write_packet(From, To, Packet, Host) ->
    gen_mod:get_module_proc(Host, ?PROCNAME) ! {call, self(), get_config},

 %   Format = get_im_transform_format(Config),
    Format = ?DEFAULT_FORMAT,
    Subject = get_subject(Format, Packet),
    Body = get_body(Format, Packet),
    Thread = get_thread(Format, Packet),
    case Subject ++ Body of
        "" -> %% don't log empty messages
            ?DEBUG("not logging empty message from ~s",[jlib:jid_to_string(From)]),
            ok;
        _ -> post_to_rabbitmq(From, To, Subject, Thread, Body)
    end.

parse_message(FromJid, ToJid, Type)->
	{From, FromBrandId} = get_memberId(FromJid),
	{To, ToBrandId} = get_memberId(ToJid),
    Format = ?DEFAULT_FORMAT,
    Subject = get_subject(Format, Packet),
    Body = get_body(Format, Packet),
    Thread = get_thread(Format, Packet),
    TimeStamp = get_timestamp(),
    #message{
    	from = From,
	 	from_brandId = FromBrandId,
    	to = To,
    	to_brandId = ToBrandId,
    	type = Type,
    	subject = Subject,
    	body = Body,
    	thread = Thread,
    	time_stamp = TimeStamp
    }.

get_memberId(Jid)->
   UserName = jlib:jid_to_string(Jid),
   [MemberId, BrandId] = get_login_data(UserName, IdMap).

get_im_transform_format(_)->
   text.

post_to_rabbitmq(From, To, Subject, Thread, Body)->

get_subject(Format, Text) ->
	parse_body(Format, xml:get_path_s(Packet, [{elem, "subject"}, cdata]).

get_body(Format, Text) ->
   parse_body(Format, xml:get_path_s(Packet, [{elem, "body"}, cdata])).

get_thread(Format, Text) ->
   parse_body(Format, xml:get_path_s(Packet, [{elem, "thread"}, cdata])).

parse_body(Format, false) -> "";
parse_body(Format, Text) -> escape(Format, Text).

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

get_memberId_communityId([])-> [];
get_memberId_communityId(UserName) ->
  case re:split(UserName,"-") of 
      [MemberId, CommunityId] -> [MemberId, CommunityId];
              {error, Reason} -> {error, Reason};
              Else -> {error, Else}
  end.

get_timestamp() ->
  R =os:timestamp(),
  calendar:now_to_universal_time(R).

get_login_data(UserName, IdMap) ->
  [MemberId, CommunityId] = get_memberId_communityId(UserName), 
  BrandIdStr = find_value(CommunityId, IdMap),
  MemberIdStr = erlang:binary_to_list(MemberId),
  [MemberIdStr, BrandIdStr]. 

find_value(Key, List) ->
  Key1 = erlang:binary_to_list(Key),
  case lists:keyfind(Key1, 2, List) of
        {_Type, _Key, Result} -> Result;
        false -> {error, not_found};
        {error, Reason} -> {error, Reason}
  end.