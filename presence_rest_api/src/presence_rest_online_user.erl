%% @author author <author@example.com>
%% @copyright YYYY author.
%% @doc Example webmachine_resource.

-module(presence_rest_online_user).
-export([init/1 
	,to_json/2
	,content_types_provided/2
	,allowed_methods/2
]).

-include_lib("webmachine/include/webmachine.hrl").

-type(wm_reqdata() :: #wm_reqdata{}).

-define(TRACE_DIR, "/tmp").

init([]) -> {ok, undefined};

init(Config) ->
	{{trace, ?TRACE_DIR}, Config}.

content_types_provided(RD, Ctx) ->
	{[{"application/json", to_json} ], RD, Ctx}.

allowed_methods(RD, Ctx) ->
	{['GET', 'HEAD', 'OPTIONS'], RD, Ctx}.

to_json(RD, Ctx) ->
	Id = get_id(id, RD),
	Resp = query_resource(Id),
	%Resp = paper2json(Id1, Title),
	{Resp, RD, Ctx}.

get_id(id, RD)->
  	wrq:path_info(id, RD).

query_resource(Id)-> 
	case Id of
		[] -> user_presence_srv:list_all_online(Id);
		Id -> user_presence_srv:list_online(Id) 
	end.
