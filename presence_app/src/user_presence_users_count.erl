%% @author author <author@example.com>
%% @copyright YYYY author.
%% @doc Example webmachine_resource.

-module(user_presence_users).
-behaviour(gen_server).

-export([init/1,
         allowed_methods/2,
         content_types_provided/2,
         content_types_accepted/2,

         from_json/2,
		 to_json/2]).

-export([start/0, stop/0]).
-export([start_link/1]).

-export([init/1, init/0,
		 handle_call/3,
		 handle_cast/2,
		 handle_info/2, 
		 terminate/2, 
		 code_change/3]).


-include_lib("webmachine/include/webmachine.hrl").
-include_lib("online_user_json.hrl").

-define(APP_JSON, "application/json").
-record(ctx, {db}).

init([]) -> 
  	error_logger:info_msg("Initialize ~p",[?SERVER]),
	{{trace, "traces"}, Config}.

allowed_methods(ReqData, Ctx) ->
    {['HEAD', 'GET', 'OPTIONS'], ReqData, Ctx}.

content_types_accepted(ReqData, Ctx) ->
    {[{?APP_JSON, from_json}], ReqData, Ctx}.

content_types_provided(ReqData, Ctx) ->
    {[{?APP_JSON, to_json}], ReqData, Ctx}.

process_post(ReqData, Ctx) ->
    [{JsonDoc, _}] = mochiweb_util:parse_qs(wrq:req_body(ReqData)),
    {struct, Doc} = mochijson2:decode(JsonDoc),
    NewDoc = ece_db:create(Ctx#ctx.db, {Doc}),
    ReqData2 = wrq:set_resp_body(NewDoc, ReqData),
    {true, ReqData2, Ctx}.

to_json(ReqData, Ctx) ->
    is_user_online(wrq:path_info(id, ReqData)),
    gen_server:call(?SERVER, {list_online_user, ReqData}).

from_json(RD, Ctx, {error, no_data}) ->
	signal_malformed(RD, Ctx).

from_json(ReqData, Ctx) ->
    case wrq:path_info(id, ReqData) of
        undefined ->
            {false, ReqData, Ctx};
        ID ->
            JsonDoc = wrq:req_body(ReqData),
            {struct, Doc} = mochijson2:decode(JsonDoc),
            NewDoc = ece_db:update(Ctx#ctx.db, ID, Doc),
            ReqData2 = wrq:set_resp_body(NewDoc, ReqData),
            {true, ReqData2, Ctx}
    end.

list_online_count(undefined)->
  Resp = #online_user_json{ count = 0,
         token = get_token()},
  ReqData2 = wrq:set_resp_body(Resp, ReqData),
  {JsonDoc, ReqData2, Ctx};

list_online_count(Since)->
  Reply = gen_server:call(?SERVER, {list_online_count, Since}),
  ReqData2 = wrq:set_resp_body(Reply, ReqData),
  {JsonDoc, ReqData2, Ctx}.

handle_call({list_online_count, Since}, From, State) ->
  Reply = user_presence_srv:list_online_count(Since),
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

get_token() ->
	user_presence_srv:generate_token().
