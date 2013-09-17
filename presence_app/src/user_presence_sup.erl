-module(user_presence_sup).

-behaviour(supervisor).

%% API
-export([start_link/1]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type, Args), {I, {I, start_link, Args}, permanent, 5000, Type, [I]}).
-define(ConfPath,"conf").
-define(ConfFile, "spark_user_presence.config").
-define(SERVER, ?MODULE).

%% ===================================================================
%% API functions
%% ===================================================================

start_link(Args) ->
    error_logger:info_msg("Starting ~p supervisor with args ~p", [?MODULE, Args]),
    supervisor:start_link({local, ?SERVER}, ?MODULE, [Args]).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================
init() -> init([]).
init(Args) ->
    error_logger:info_msg("Starting dependency apps ~p~n", Args),
	Apps = [syntax_tools, 
			compiler, 
			crypto,
			public_key,
			ssl,
			goldrush, 
			lager, 
			parse_trans,
			json_rec,
			inets,
    		ranch, 
    		cowboy, 
			mnesia],
 	app_util:start_apps(Apps),
 	Opts1 = 
 	Opts2 = 
	Children = lists:flatten([
    	?CHILD(user_presence_srv, worker, Args),
    	?CHILD(user_presence_db, worker, Args)
    ]),
    error_logger:info_msg("Starting apps ~p ~p ~n", [user_presence_srv, user_presence_db]),
    {ok,{{one_for_one,5,10}, Children}}.

