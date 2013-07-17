-module(app_util).

-export([start_app/1,
		 stop_app/1]).

-export([ensure_binary/1]).

-export([is_process_alive/1]).

-export([os_now/0, timespan/2]).

-export([config_val/3]).


-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

start_app(ok)-> ok;
start_app(App) when is_atom(App) ->
	start_app(application:start(App));
start_app({error, {already_started, App}})
		when is_atom(App) -> ok;
start_app({error, {Reason, App}}) 
		when is_atom(App) ->
	{error, {Reason, App}};
start_app({E, {Reason, App}}) ->
	{E, {Reason, App}};
start_app(_)-> {error, badarg}.

stop_app(ok)-> ok;
stop_app({error,{not_started,App}})
		when is_atom(App)-> ok;
stop_app({error, {Reason, App}}) 
		when is_atom(App) ->
	{error, {Reason, App}};
stop_app({E, {Reason, App}})-> 
	{E, {Reason, App}};
stop_app(_)-> {error, badarg}.

is_process_alive(Pid) when is_pid(Pid)->
	true = erlang:is_process_alive(Pid).

-spec ensure_binary(any())-> bitstring().
ensure_binary(undefined)-> undefined;
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

-spec config_val(atom(), list(), any()) -> any().
config_val(Key, List, Default) -> {ok, proplists:get_value(Key, List, Default)}.

%% ===================================================================
%% EUnit tests
%% ===================================================================
-ifdef(TEST).
app_helper_test_() ->
    { setup,
      fun setup/0,
      fun cleanup/1,
      [
%       {"Should start app",fun start_app_test/0},      
%       {"Should start app",fun start_app_test/0}	
      ]
    }.

setup() ->
    ok.

cleanup(_Ctx) ->
    ok.



-endif.