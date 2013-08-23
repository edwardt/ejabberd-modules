%% Feel free to use, reuse and abuse the code in this file.

%% @private
-module(ejabberd_rest_api_app).
-behaviour(application).

%% API.
-export([start/2]).
-export([stop/1]).

%% API.

start(_Type, _Args) ->
	Dispatch = cowboy_router:compile([
		{'_', [
			{"/ejabberd_rest_api", ejabberd_rest_api_handler, []},
			{"/", cowboy_static, [
				{directory, {priv_dir, ejabberd_rest_api, []}},
				{file, <<"index.html">>},
				{mimetypes, {fun mimetypes:path_to_mimes/2, default}}
			]}
		]}
	]),
	{ok, _} = cowboy:start_http(http, 100, [{port, 8080}], [
		{env, [{dispatch, Dispatch}]}
	]),
	ejabberd_rest_api_sup:start_link().

stop(_State) ->
	ok.
