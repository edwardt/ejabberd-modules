-module(user_presence_app).

-behaviour(application).

-export([start/0, stop/0]).

%% Application callbacks
-export([start/2, stop/1]).

-define(SERVER, ?MODULE).
-define(ConfPath,"conf").
-define(ConfFile, "spark_user_presence.config").

start()->
    app_util:start_app(?SERVER).

stop()->
	app_util:stop_app(?SERVER).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
	Args = {?ConfPath, ?ConfFile},
	user_presence_api_sup:start_link(Args),
    user_presence_sup:start_link(Args).

stop(_State) ->
    ok.
