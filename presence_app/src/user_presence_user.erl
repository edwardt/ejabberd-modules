%% @author author <author@example.com>
%% @copyright YYYY author.
%% @doc Example webmachine_resource.

-module(user_presence_user).
-behaviour(gen_server).

-export([init/1,
         allowed_methods/2,
         content_types_provided/2,
         content_types_accepted/2,
         to_json/2]).

-export([start_link/1]).

-export([init/1, init/0,
		 handle_call/3,
		 handle_cast/2,
		 handle_info/2, 
		 terminate/2, 
		 code_change/3]).


-include_lib("webmachine/include/webmachine.hrl").
-include_lib("user_webpresence.hrl").

-define(APP_JSON, "application/json").
-define(SERVER, ?MODULE).
-record(ctx, {
	client
}).

init() -> 
    error_logger:info_msg("Initialize ~p",[?SERVER]),
    {{trace, "traces"}, #ctx{}}.

init(Config)->
    error_logger:info_msg("Initialize ~p",[?SERVER]), 
    {{trace, "traces"}, Config}.

start_link() -> start_link([]).
start_link(Args)->
    gen_server:start_link({local, ?SERVER}, ?MODULE, Args ,[]).


allowed_methods(ReqData, Ctx) ->
    {['HEAD', 'GET', 'OPTIONS'], ReqData, Ctx}.

content_types_accepted(ReqData, Ctx) ->
    {[{?APP_JSON, from_json}], ReqData, Ctx}.

content_types_provided(ReqData, Ctx) ->
    {[{?APP_JSON, to_json}], ReqData, Ctx}.


to_json(ReqData, Ctx) ->
    is_user_online(wrq:path_info(id, ReqData)),
    gen_server:call(?SERVER, {web_pres, ReqData}).

is_user_online(undefined)->
  Resp = #user_webpresence{memberId = <<"">>, 
         presence = <<"offline">>,
         token = get_token()},
  ReqData2 = wrq:set_resp_body(Resp, ReqData),
  {JsonDoc, ReqData2, Ctx};

is_user_online(Id)->
  Reply = gen_server:call(?SERVER, {web_pres, Id}),
  ReqData2 = wrq:set_resp_body(Reply, ReqData),
  {JsonDoc, ReqData2, Ctx}.

handle_call({web_pres, Id}, From, State) ->
  Reply = user_presence_srv:list_online(Id),
  {reply, Reply, State};

handle_call(_Request, _From, State) ->
  Reply = {error, function_clause},
  {reply, Reply, State}.

handle_cast(Info, State) ->
  erlang:display(Info),
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State)->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.  

signal_malformed_request(RD, Ctx) ->
	{{halt, 400}, RD, Ctx}.
get_token()->
  user_presence_srv:generate_token().
