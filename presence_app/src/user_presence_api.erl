%% @author author <author@example.com>
%% @copyright YYYY author.

%% @doc user_presence_api startup code

-module(user_presence_api).
-author('author <author@example.com>').
-export([start/0, start_link/0, stop/0]).

ensure_started(App) ->
    case application:start(App) of
        ok ->
            ok;
        {error, {already_started, App}} ->
            ok
    end.

%% @spec start_link() -> {ok,Pid::pid()}
%% @doc Starts the app for inclusion in a supervisor tree
start_link() ->
    application:ensure_started(inets),
    application:ensure_started(crypto),
    application:ensure_started(mochiweb),
    application:set_env(webmachine, webmachine_logger_module, 
                        webmachine_logger),
    ensure_started(webmachine),
    user_presence_api_sup:start_link().

%% @spec start() -> ok
%% @doc Start the user_presence_api server.
start() ->
    application:ensure_started(inets),
    application:ensure_started(crypto),
    application:ensure_started(mochiweb),
    application:set_env(webmachine, webmachine_logger_module, 
                        webmachine_logger),
    ensure_started(webmachine),
    application:start(user_presence_api).

%% @spec stop() -> ok
%% @doc Stop the user_presence_api server.
stop() ->
    Res = application:stop(user_presence_api),
    application:stop(webmachine),
    application:stop(mochiweb),
    application:stop(crypto),
    application:stop(inets),
    Res.
