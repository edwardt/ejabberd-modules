-module(spark_rabbitmq_consumer_sup).
-behaviour(supervisor).

%% API
-export([start_link/0, start_link/1]).

%% Supervisor callbacks
-export([init/0,init/1]).

-include("amqp_client/include/amqp_client_internal.hrl").

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).
-define(DEFAULT_RESTART,{{one_for_one, 5, 10}, []}).
-define(SPAWN_OPTS, {fullsweep_after, 60}).
-define(CONSUMER_MOD, spark_rabbit_consumer).
-define(SERVER, ?MODULE).
-define(CONFPATH,"conf").
-define(AMQP_CONF, "spark_amqp.config").
-define(REST_CONF, "spark_rest.config").

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
	Args = [{?CONFPATH, ?AMQP_CONF, ?REST_CONF}],
	start_link(Args).
	 
start_link(Args) ->
    error_logger:info_msg("Starting ~p cluster ~n",[?SERVER]),
    supervisor:start_link({global, ?SERVER}, ?MODULE, Args).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init()->
    ensure_dependency_started(),
    ConfPath = app_config_util:app_get_env(?SERVER, conf_path,?CONFPATH),
    AmqpConf = app_config_util:app_get_env(?SERVER, amqp_conf,?AMQP_CONF),
    RestConf = app_config_util:app_get_env(?SERVER, rest_conf, ?REST_CONF),
    ConsumerArgs = [{ConfPath, AmqpConf, RestConf}],
    init(ConsumerArgs).


init(ConsumerArgs) ->
    error_logger:info_msg("[~p] Starting with args ~n", [?SERVER]),
	ShouldCluster = 
	     app_config_util:app_get_env(?SERVER, should_cluster, true),	
	     
    {ok, {{one_for_one, 10, 10}, 
    	  child_specs(ShouldCluster, ConsumerArgs)}}.

child_specs(true, ConsumerArgs)->
    error_logger:info_msg("[~p] Starting with cluster mode ~p ~n", [?SERVER, ConsumerArgs]),
    Name = spark_chat_consumer_cluster,
	[{spark_rabbit_consumer_chat,
	 {spark_rabbit_consumer_chat, start_link, [Name, ConsumerArgs]},
	 permanent, ?MAX_WAIT, worker, [spark_rabbit_consumer_chat]}
	];
	
	
child_specs(false, ConsumerArgs)->
    error_logger:info_msg("[~p] Starting with simple app mode ~p ~n", [?SERVER, ConsumerArgs]),

    [{spark_rabbitmq_consumer, {spark_rabbit_consumer, start_link,
	 ConsumerArgs},
	 permanent, ?MAX_WAIT, worker, [spark_rabbit_consumer]}
	].  

ensure_dependency_started()->
  error_logger:info_msg("[~p] Starting depedenecies", [?SERVER]),
  Apps = [syntax_tools, 
	  compiler, 
	  crypto,
	  public_key,
%	  gen_server2,
	  ssl, 
%	  goldrush, 
	  rabbit_common,
	  amqp_client,
%	  restc,
	  inets],
  error_logger:info_msg("[~p] Going to start apps ~p",
			 [?SERVER, lists:flatten(Apps)]),
  app_util:start_apps(Apps),
  %ok = lager:start(),
  error_logger:info_msg("[~p] Started depedenecies ~p",
			 [?SERVER, lists:flatten(Apps)]),
  ok.

  
