-module(spark_rabbit_consumer).
-behaviour(amqp_gen_consumer).

-include("rabbit_farms.hrl").
-include("rabbit_farms_internal.hrl").
-include("spark_restc_config.hrl").
-include_lib("lager/include/lager.hrl").
-include("amqp_client/include/amqp_gen_consumer_spec.hrl").

-define(SERVER,?MODULE).
-define(APP,rabbit_consumer).
-define(DELAY, 10).
-define(RECON_TIMEOUT, 5000).
-define(INITWAIT, 3000).
-define(ETS_FARMS,ets_rabbit_farms).
-define(RESPONSE_TIMEOUT,2000).
-define(CONFPATH,"conf").
-define(AMQP_CONF, "spark_amqp.config").
-define(REST_CONF, "spark_rest.config").
-define(HEARTBEAT, 5).

%% API
-export([start/0, stop/0]).
-export([init/1, 
	 handle_consume_ok/3, handle_consume/3, 		
	 handle_cancel_ok/3,handle_cancel/2, handle_deliver/3, 		 	  handle_info/2, handle_call/3,
         terminate/2]).

-record(state, {
    name = <<"">>, 
    amqp_queue_declare,
    amqp_queue_bind ,
    amqp_connection,
    app_env
}).
-record(app_env,{
    transform_module = {undefined, not_loaded},
    restart_timeout = 5000
}).

-spec start_link(list()) -> pid() | {error, term()}.
start_link(Args)->
   error_logger:info_msg("~p gen_server starting  ~p ~n",
		 [?SERVER, Args]),
   Pid = start(),
   error_logger:info_msg("~p started with Pid ~p~n",
		 [?SERVER, Pid]), 
   Pid.


-spec start() -> ok.
start()->
   error_logger:info_msg("Starting application ~p",[?SERVER]),
   ok = ensure_dependency_started(),
   ConfPath = application:get_env(?SERVER, conf_path,?CONFPATH),
   AmqpConf = application:get_env(?SERVER, amqp_conf,?AMQP_CONF),
   RestConf = application:get_env(?SERVER, rest_conf, ?REST_CONF),
   error_logger:info_msg("Fetching configuration files ~p ~p ~p",
			  [ConfPath, AmqpConf, RestConf]),
   R = amqp_gen_consumer:start_link(?SERVER,
		 [{ConfPath, AmqpConf, RestConf}]),
   
   error_logger:info_msg("Registered ~p with amqp_gen_consumer with result: ~p",[?SERVER, R]), 
   R.

-spec stop() -> ok.
stop()->
   error_logger:info_msg("Terminating app: ~p ", [?SERVER]),
   %R = amqp_gen_consumer:terminate(?SERVER),
   %gen_server:call(?SERVER,{stop, normal})
   ok.

ensure_dependency_started()->
  error_logger:info_msg("[~p] Starting depedenecies", [?SERVER]),
  Apps = [syntax_tools, 
	  compiler, 
	  crypto,
	  public_key,
	  gen_server2,
	  ssl, 
	  goldrush, 
	  rabbit_common,
	  amqp_client,
	  inets, 
	  restc],
  error_logger:info_msg("[~p] Going to start apps ~p",
			 [?SERVER, lists:flatten(Apps)]),
  app_util:start_apps(Apps),
  %ok = lager:start(),
  error_logger:info_msg("[~p] Started depedenecies ~p",
			 [?SERVER, lists:flatten(Apps)]),
  ok.


%%%===================================================================
%%% Internal API
%%%===================================================================


init(Args)->
    process_flag(trap_exit, true),
    {ConfPath, AmqpConf, RestConf} = Args,
    error_logger:info_msg("Starting  ~p with config path ~p, amqp config file ~p, spark rest config ~p",
			   [?SERVER, ConfPath, AmqpConf, RestConf]),
    ConfList= read_from_config(ConfPath, AmqpConf), 
    Ret = setup_amqp(ConfList),
    error_logger:info_msg("Starting  started with state ~p",
			   [?SERVER, Ret]),
    erlang:send_after(?INITWAIT, register_to_channel ,self()),
    {ok, Ret}.

setup_rabbitmq__runtime_env(ConfList)->
  {ok, Channel, AmqpParams} = channel_setup(ConfList),
  ExchangeDeclare = exchange_setup(Channel, ConfList),
  QueueDeclare = queue_setup(Channel, ConfList),
  {ok,  Channel, AmqpParams, ExchangeDeclare, QueueDeclare}.

setup_amqp(ConfList)->
 %[AmqpCon, Exchange, Queue, App_Env] = ConfList,
  error_logger:info_msg("~p establishing amqp connection to server",[?SERVER]),

%  {ok, Channel, AmqpParams} = channel_setup(ConfList),
%  ExchangeDeclare = exchange_setup(Channel, ConfList),
%  QueueDeclare = queue_setup(Channel, ConfList),
  {ok,  Channel, AmqpParams, ExchangeDeclare, QueueDeclare} =
	setup_rabbitmq__runtime_env(ConfList),
  Queue = QueueDeclare#'queue.declare'.queue,
  Name =
  Exchange =  ExchangeDeclare#'exchange.declare'.exchange,
  RoutingKey = spark_rabbit_config:get_routing_key(ConfList),
  QueueBind = queue_bind(Channel, Queue, Exchange, RoutingKey),
  AppEnv = get_app_env(ConfList),
  error_logger:info_msg("spark_amqp_session is configured",[]),
  #state{ 
    name = Name, 
    amqp_queue_declare = QueueDeclare,
    amqp_queue_bind = QueueBind,
    amqp_connection = AmqpParams,
    app_env = AppEnv
  }.


read_from_config({file_full_path, File})->
   {ok, [L]} = app_config_util:load_config_file(File),
   L.

read_from_config(Path, File) ->
   {ok, [L]} = app_config_util:load_config(Path,File),
   L.

-spec get_app_env(list()) -> #app_env{}.	
get_app_env(ConfList)->
  {ok, AppConfList} = app_config_util:config_val(app_env, ConfList, []),
  TransformMod = proplists:get_value(transform_module,AppConfList),
  Restart_timeout = proplists:get_value(restart_timeout,AppConfList),
  #app_env{
    transform_module = {TransformMod, not_loaded},
    restart_timeout = Restart_timeout}. 

-spec channel_setup(list()) -> {ok, pid()} | {error, term()}.
channel_setup(ConfList)->
  error_logger:info_msg("Setting up communication: ~p",[ConfList]),  
  AmqpParams = spark_rabbit_config:get_connection_setting(ConfList), 
  {ok, Connection} = amqp_connection:start(AmqpParams),
  error_logger:info_msg("AMQP connection established with pid: ~p",[Connection]),
  error_logger:info_msg("Setting up channel: ~p",[AmqpParams]), 
  {ok, Channel} = amqp_connection:open_channel(Connection),
  error_logger:info_msg("AMQP channel established with pid: ~p",[Channel]),
  {ok, Channel, AmqpParams}.

exchange_setup(Channel, ConfList)->
  ExchangeDeclare = spark_rabbit_config:get_exchange_setting(ConfList),
  {'exchange.declare_ok'}  = amqp_channel:call(Channel, ExchangeDeclare), 
  ExchangeDeclare.
  
queue_setup(Channel, ConfList)->
  QueueDeclare = spark_rabbit_config:get_queue_setting(ConfList),
  {'queue.declare_ok', _, _, _} = amqp_channel:call(Channel, QueueDeclare),
  QueueDeclare.

queue_bind(Channel, Queue, Exchange, RoutingKey) ->
  QueueBind = spark_rabbit_config:get_queue_bind(Queue, Exchange, RoutingKey),
  {'queue.bind_ok'}  = amqp_channel:call(Channel, QueueBind),
  QueueBind.

amqp_channel(AmqpParams) ->
  error_logger:info_msg("Checking for existing connection with ~p",[AmqpParams]),
  case maybe_new_pid({AmqpParams, connection},
                     fun() -> amqp_connection:start(AmqpParams) end) of
    {ok, Client} ->
        error_logger:info_msg("Found existing connection with ~p",[Client]),
      maybe_new_pid({AmqpParams, channel},
                    fun() -> amqp_connection:open_channel(Client) end);
    Error -> Error
  end.

-spec register_default_consumer(pid(), pid()) -> ok | {error, term()}.
register_default_consumer(ChannelPid, ConsumerPid) 
	when is_pid(ChannelPid), is_pid(ConsumerPid) ->
  amqp_channel:call_consumer(ChannelPid, 
			     {register_default_consumer, ConsumerPid});

register_default_consumer(AmqpParams, ConsumerPid) 
	when is_record(AmqpParams, amqp_params_network),
	     is_pid(ConsumerPid)-> 
  case amqp_channel(AmqpParams) of
	{ok, Pid} -> error_logger:info_msg("Register channel ~p with consumer ~p",[Pid, ConsumerPid]),
		    register_default_consumer(Pid, ConsumerPid);
	Else -> error_logger:error_msg("Failed register consumer ~p to channel. Reason: ~p",[ConsumerPid, Else]), Else

  end. 


maybe_new_pid(Group, StartFun) ->
  case pg2:get_closest_pid(Group) of
    {error, {no_such_group, _}} ->
      pg2:create(Group),
      maybe_new_pid(Group, StartFun);
    {error, {no_process, _}} ->
      case StartFun() of
        {ok, Pid} ->
          pg2:join(Group, Pid),
          {ok, Pid};
        Error -> Error
      end;
    Pid -> {ok, Pid}
  end.


%%%===================================================================
%%% amqp_gen_consumer callbacks
%%%===================================================================
handle_consumer()->


handle_consume_ok()->


handle_cancel()->

handle_cancel_ok()->

handle_deliver()->


handle_info(register_to_channel, State)->
  AmqpParams =  State#amqp_connection, 
  register_default_consumer(AmqpParams, self()),
  {noreply, State}.   

handle_info({'DOWN', MRef, process, Pid, Info}, State)->
  error_logger:error_msg("Connection down, ~p ~p",[Pid, Info]),
  {noreply, State}.

handle_info({'DOWN', _MRef, process, Pid, Info}, _Len, State)->
  error_logger:error_msg("Connection down, ~p ~p",[Pid, Info]),
  {noreply, State}.

terminate(Reason, State) ->
  error_logger:info_msg("[~p] Termination ~p",[?SERVER, Reason]),
  ok

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

