%% @author author <author@example.com>
%% @copyright YYYY author.
%% @doc Example webmachine_resource.

-module(user_presence_api_resource).
-behaviour(gen_server),

-export([init/1,
         allowed_methods/2,
         content_types_provided/2,
         content_types_accepted/2,
         finish_request/2,
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
-define(APP_JSON, "application/json").
-record(ctx, {db}).

init([]) -> 
	{{trace, "traces"}, Config}.

allowed_methods(ReqData, Ctx) ->
    {['HEAD', 'GET', 'OPTIONS'], ReqData, Ctx}.

content_types_accepted(ReqData, Ctx) ->
    {[{?APP_JSON, from_json}], ReqData, Ctx}.

content_types_provided(ReqData, Ctx) ->
    {[{?APP_JSON, to_json}], ReqData, Ctx}.

finish_request(ReqData, Ctx) ->
    ece_db_sup:terminate_child(Ctx#ctx.db),
    {true, ReqData, Ctx}.

process_post(ReqData, Ctx) ->
    [{JsonDoc, _}] = mochiweb_util:parse_qs(wrq:req_body(ReqData)),
    {struct, Doc} = mochijson2:decode(JsonDoc),
    NewDoc = ece_db:create(Ctx#ctx.db, {Doc}),
    ReqData2 = wrq:set_resp_body(NewDoc, ReqData),
    {true, ReqData2, Ctx}.

to_json(ReqData, Ctx) ->
    case wrq:path_info(id, ReqData) of
        undefined ->
            All = ece_db:all(Ctx#ctx.db),
            {All, ReqData, Ctx};
        ID ->
            JsonDoc = ece_db:find(Ctx#ctx.db, ID),
            {JsonDoc, ReqData, Ctx}
    end.

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


handle_call(_Request, _From, State) ->
  Reply = {error, function_clause},
  {reply, Reply, State}.

-spec handle_cast(tuple(), state()) -> {noreply, state()}.
handle_cast(Info, State) ->
  erlang:display(Info),
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State)->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.  



-spec signal_malformed_request(wm_reqdata(), any())-> {{halt, 400}, wm_reqdata(), any()}
signal_malformed_request(RD, Ctx) ->
	{{halt, 400}, RD, Ctx};
