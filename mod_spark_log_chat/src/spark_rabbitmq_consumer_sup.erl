-module(spark_rabbitmq_consumer_sup).
-behaviour(supervisor2).

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
    supervisor2:start_link({local, ?SERVER}, ?MODULE, []).
start_link(Args) ->
    supervisor2:start_link({local, ?SERVER}, ?MODULE, Args).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init()->
    ConfPath = application:get_env(?SERVER, conf_path,?CONFPATH),
    AmqpConf = application:get_env(?SERVER, amqp_conf,?AMQP_CONF),
    RestConf = application:get_env(?SERVER, rest_conf, ?REST_CONF),
    ConsumerArgs = {ConfPath, AmqpConf, RestConf},
    init(ConsumerArgs).

init(ConsumerArgs) ->
    {ok, {{one_for_one, 10, 10}, child_specs(ConsumerArgs)}}.

child_specs(ConsumerArgs)->
    [{spark_rabbitmq_consumer, {amqp_gen_consumer, start_link,
	[?CONSUMER_MOD, ConsumerArgs]},
	 permanent, ?MAX_WAIT, worker, [amqp_gen_consumer]}
	].    
