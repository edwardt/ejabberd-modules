-module(user_presence_app).

-behaviour(application).

-export([start/0, stop/0]).

%% Application callbacks
-export([start/2, stop/1]).

-define(SERVER, ?MODULE).

start()->
    app_util:start_app(?SERVER).

stop()->
	app_util:stop_app(?SERVER).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
    user_presence_sup:start_link().

stop(_State) ->
    ok.
