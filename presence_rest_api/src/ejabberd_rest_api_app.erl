%% @private
-module(ejabberd_rest_api_app).
-behaviour(application).

%% API.
-export([start/0, start/2]).
-export([stop/1]).

%% API.

start()->
	reloader:start(),
    Apps = [ 
    		syntax_tools, 
			compiler,
    		ssl, 
    		public_keys, 
    		crypto, 
    		inets,
    		syntax_tools,
    		compiler,
   % 		goldrush,
    		mnesia, 
    		ranch,
    		parse_trans,
    		json_rec,
    		cowboy
    		],
    app_util:start_apps(Apps).
    

start(_Type, _Args) ->
    Configs = getConfig(),
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
	ejabberd_rest_api_sup:start_link(Args).

stop(_State) ->
	ok.
	
get_config(Args)->
	error_logger:info_msg("Initiating user_presence_db ~p with config ~p", [?SERVER, Args]),
  	Start = app_util:os_now(),
  	{Path, File} = Args,
	
