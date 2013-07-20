%% @author author <author@example.com>
%% @copyright YYYY author.

%% @doc Callbacks for the user_presence_api application.

-module(user_presence_api_app).
-author('author <author@example.com>').

-behaviour(application).
-export([start/2,stop/1]).


%% @spec start(_Type, _StartArgs) -> ServerRet
%% @doc application start callback for user_presence_api.
start(_Type, _StartArgs) ->
    user_presence_api_sup:start_link().

%% @spec stop(_State) -> ServerRet
%% @doc application stop callback for user_presence_api.
stop(_State) ->
    ok.
