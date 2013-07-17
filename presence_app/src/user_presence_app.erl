-module(user_presence_app).

-behaviour(application).

%% Application callbacks
-export([start/0, start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
    user_presence_sup:start_link().
start()->
    user_presence_sup:start_link().
stop(_State) ->
    ok.
