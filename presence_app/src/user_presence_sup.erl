-module(user_presence_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).
-define(ConfPath,"conf").
-define(ConfFile, "spark_amqp.config").
-define(SERVER, ?MODULE).

%% ===================================================================
%% API functions
%% ===================================================================

start_link()->
	start_link([{?ConfPath, ?ConfFile}]).
start_link(Args) ->
    error_logger:info_msg("Starting ~p supervisor with args ~p", [?MODULE, Args]),
    supervisor:start_link({local, ?SERVER}, ?MODULE, Args).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================
init()->
   init([]).
init(Args) ->
	Children = lists:flatten([
    ?CHILD(user_presence_srv, worker),
    ?CHILD(user_presence_db, worker)
    ]),
    {ok,{{one_for_one,5,10}, Children}}.

