%% @author author <author@example.com>
%% @copyright YYYY author.

%% @doc presence_rest_api startup code

-module(presence_rest_api).
-author('author <author@example.com>').
-export([start/0, 
	start_link/0, 
	stop/0]).

%% @spec start_link() -> {ok,Pid::pid()}
%% @doc Starts the app for inclusion in a supervisor tree
start_link() ->
    app_util:start_app(inets),
    app_util:start_app(crypto),
    app_util:start_app(mochiweb),
    application:set_env(webmachine, webmachine_logger_module, 
                        webmachine_logger),
    app_util:start_app(webmachine),
    presence_rest_api_sup:start_link().

%% @spec start() -> ok
%% @doc Start the presence_rest_api server.
start() ->
    app_util:start_app(inets),
    app_util:start_app(crypto),
    app_util:start_app(mochiweb),
    application:set_env(webmachine, webmachine_logger_module, 
                        webmachine_logger),
    app_util:start_app(webmachine),
    application:start(presence_rest_api).

%% @spec stop() -> ok
%% @doc Stop the presence_rest_api server.
stop() ->
    Res = application:stop(presence_rest_api),
    application:stop(webmachine),
    application:stop(mochiweb),
    application:stop(crypto),
    application:stop(inets),
    Res.
