%% @author author <author@example.com>
%% @copyright YYYY author.

%% @doc user_presence_api startup code

-module(user_presence_api).
-author('author <author@example.com>').
-export([start/0, start_link/0, stop/0]).

%% @spec start_link() -> {ok,Pid::pid()}
%% @doc Starts the app for inclusion in a supervisor tree
start_link() ->
    app_util:start_app(inets),
    app_util:start_app(crypto),
    app_util:start_app(mochiweb),
    application:set_env(webmachine, webmachine_logger_module, 
                        webmachine_logger),
    app_util:start_app(webmachine),
    user_presence_api_sup:start_link().

%% @spec start() -> ok
%% @doc Start the user_presence_api server.
start() ->
    app_util:start_app(inets),
    app_util:start_app(crypto),
    app_util:start_app(mochiweb),
    application:set_env(webmachine, webmachine_logger_module, 
                        webmachine_logger),
    app_util:start_app(webmachine),
    application:start(user_presence_api).

%% @spec stop() -> ok
%% @doc Stop the user_presence_api server.
stop() ->
    Res = app_util:stop_app(user_presence_api),
    app_util:stop_app(webmachine),
    app_util:stop_app(mochiweb),
    app_util:stop_app(crypto),
    app_util:stop_app(inets),
    Res.
