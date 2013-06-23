-module(mod_spark_log_chat_sup).
-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/0,init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).
-define(DEFAULT_RESTART,{{one_for_one, 5, 10}, []}).
-define(SPAWN_OPTS, {fullsweep_after, 60}).

-include_lib("lager/include/lager.hrl").
%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, [{spawn_opts, ?SPAWN_OPTS}]).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================
init()->init([]).

init([]) ->
    app_helper:ensure_app_started(spark_app_config),
    app_helper:ensure_app_started(lager),
    Children = [?CHILD(spark_amqp_client, worker),
		?CHILD(mod_spark_log_chat_srv, worker)
		],
    {ok, {?DEFAULT_RESTART, Children}};

init(_Args)->
    init([]).
