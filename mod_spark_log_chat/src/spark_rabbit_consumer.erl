-module(spark_rabbit_consumer).
-behaviour(amqp_gen_consumer).

%-behaviour(gen_server2).

-include("rabbit_farms.hrl").
-include("rabbit_farms_internal.hrl").
-include("spark_restc_config.hrl").
-include_lib("lager/include/lager.hrl").
-include("amqp_client/include/amqp_gen_consumer_spec.hrl").

-define(SERVER,?MODULE).
-define(APP,rabbit_consumer).
-define(DELAY, 10).
-define(RECON_TIMEOUT, 5000).
-define(INITWAIT, 3).
-define(ETS_FARMS,ets_rabbit_farms).
-define(RESPONSE_TIMEOUT,2000).
-define(CONFPATH,"conf").
-define(AMQP_CONF, "spark_amqp.config").
-define(REST_CONF, "spark_rest.config").
-define(HEARTBEAT, 5).

%% API
-export([start_link/1, start_link/0]).
-export([start/0, stop/0]).
-export([init/1, 
	 handle_consume_ok/3, handle_consume/3, 		
	 handle_cancel_ok/3,handle_cancel/2,
	 handle_deliver/3,
	 handle_info/2, handle_call/3,
         terminate/2]).

-export([register_default_consumer/0,
         subscribe/0,
         unsubscribe/0,
         subscribe/1,
         unsubscribe/1]).

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

start_link()->
   {ok, ConfPath} = application:get_env(?SERVER, conf_path),
   {ok, AmqpConf} = application:get_env(?SERVER, amqp_conf),
   {ok, RestConf} = application:get_env(?SERVER, rest_conf),
   start_link({ConfPath, AmqpConf, RestConf}).

-spec start_link(list()) -> pid() | {error, term()}.
start_link(Args)->
   error_logger:info_msg("~p gen_server starting  ~p ~n",
		 [?SERVER, Args]),
   R = amqp_gen_consumer:start_link(?SERVER, [Args]),
   error_logger:info_msg("amqp_gen_consumer start_link ~p",[R]), 
   R.

start()->
   {ok, ConfPath} = application:get_env(?SERVER, conf_path),
   {ok, AmqpConf} = application:get_env(?SERVER, amqp_conf),
   {ok, RestConf} = application:get_env(?SERVER, rest_conf),
   Args = [{ConfPath, AmqpConf, RestConf}],
   start(Args).
  
-spec start() -> ok.
start(Args)->
   [{ConfPath, AmqpConf, RestConf}] = Args,
   error_logger:info_msg("Starting application ~p",[?SERVER]),
 %  ensure_dependency_started()
   ok.

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

register_default_consumer() ->
%  amqp_gen_consumer:call
  gen_server2:call(?SERVER, register_default_consumer). 

subscribe()-> subscribe(self()).
subscribe(Pid)->
  error_logger:info_msg("Subscribe, subscription",[]),
 % Pid = self(),  
  Method = #'basic.consume'{},
  error_logger:info_msg("Sending subscription request to amqp_gen_consumer pid ~p", [Pid]),
  Reply =  amqp_gen_consumer:call_consumer(Pid, Method, []),
  error_logger:info_msg("Subscritpion reply from amqp_gen_consumer ~p", [Reply]),
  Reply.
  
unsubscribe() -> unsubscribe(self()).
unsubscribe(Pid)->  
  error_logger:info_msg("Unsubscription: ~p",[Pid]),
 % Pid = self(),  
  Method = #'basic.cancel'{},
  error_logger:info_msg("Cancelling subscription request to amqp_gen_consumer pid ~p", [Pid]),
  Reply =  amqp_gen_consumer:call_consumer(Pid, Method, []),
  error_logger:info_msg("Cancelling Subscritpion reply from amqp_gen_consumer ~p", [Reply]),
  Reply.



%  gen_server2:call(?SERVER, unsubscribe).



%%%===================================================================
%%% Internal API
%%%===================================================================

 
init(Args)->
    process_flag(trap_exit, true),
    [{ConfPath, AmqpConf, RestConf}] = Args,
    error_logger:info_msg(" Starting  ~p with config path ~p, amqp config file ~p, spark rest config ~p",
			   [?SERVER, ConfPath, AmqpConf, RestConf]),
    ConfList= read_from_config(ConfPath, AmqpConf), 
    Ret = setup_amqp(ConfList),
    error_logger:info_msg("[~p] Started initiated with state ~p",
			   [?SERVER, Ret]),
%    {ok,  Channel, AmqpParams, ExchangeDeclare, QueueDeclare} = Ret,
%    register_default_consumer(ChannelPid, ConsumerPid),
    %erlang:send_after(?INITWAIT, register_to_channel  ,self()),
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

  error_logger:info_msg("spark rabbit consumer amqp_session is configured",[]),
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
  IsLoaded = ensure_load(TransformMod, false),
  #app_env{
    transform_module = IsLoaded,
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

-spec extract_content(#amqp_msg{}) -> 
	{[binary()], binary(), binary(), binary()}.

extract_content(Content) when is_record(Content, amqp_msg)->
    #amqp_msg{props = Props, payload = Payload} = Content,
    #'P_basic'{
    	content_type = ContentType,
    	message_id = MessageId
    } = Props,
    {Props, Payload, ContentType, MessageId}.
 


%%%===================================================================
%%% amqp_gen_consumer callbacks
%%%===================================================================
handle_consume(Method, Args, State)->
   error_logger:info_msg("[~p] is handling subscription. My pid is ~p",[?SERVER, self()]),

   AmqpParams = State#state.amqp_connection,
   ConsumerPid = self(),
   
   #'basic.consume'{queue = Queue, no_ack = false} = Method,
   
   QueueDeclare = State#state.amqp_queue_declare,
   Queue2 = QueueDeclare#'queue.declare'.queue,   
   Method2 = #'basic.consume'{queue = Queue2, no_ack = false},
   error_logger:info_msg("[~p] is establishing amqp session for subcription. My pid is ~p",[?SERVER, self()]),
   Reply = case amqp_channel(AmqpParams) of
	{ok, ChannelPid} -> 
		    error_logger:info_msg("Register channel ~p with consumer ~p on Queue ~p", [ChannelPid, ConsumerPid, Queue]),
		    amqp_channel:subscribe(ChannelPid, Method2, ConsumerPid);
	Else -> error_logger:error_msg("Failed register consumer ~p to channel on Queue ~p Reason: ~p",[ConsumerPid, Queue, Else]), Else
   end, 
   {reply, Reply, State}. 

handle_consume_ok(Method, Args, State)->
   error_logger:info_msg("subscribe ok Ctag ~p on pid ~p",
			[?SERVER,self()]),  
   #'basic.consume_ok'{consumer_tag = Reply} = Method,
   error_logger:info_msg("subscribe ok Ctag ~p on pid ~p",
			[Reply, self()]),
   {reply, Reply, State}.    


handle_cancel(Method, State)->
   error_logger:info_msg("[~p] is handling unsubscription. My pid is ~p",
			[?SERVER, self()]),   

   #'basic.cancel'{consumer_tag = CTag} = Method,
   AmqpParams = State#state.amqp_connection,
   ConsumerPid = self(),
   Reply = case amqp_channel(AmqpParams) of
	{ok, ChannelPid} -> 
		    error_logger:info_msg("Register channel ~p with consumer ~p", [ChannelPid, ConsumerPid]),
		    amqp_channel:call(ChannelPid, Method);
	Else -> error_logger:error_msg("Failed register consumer ~p to channel. Reason: ~p",[ConsumerPid, Else]), Else
   end,   
   error_logger:info_msg("unsubscribe from Channel Ctag ~p on pid ~p",[CTag ,ConsumerPid]),
   {reply, Reply, State}.

handle_cancel_ok(Method, Args, State)->
   #'basic.cancel_ok'{consumer_tag = Reply} = Method,
   error_logger:info_msg("unsubscribe ok Ctag ~p on pid ~p",	[Reply , self()]),
   {reply, Reply, State}. 

handle_deliver(Method, Content, State)->
   Start = app_util:get_printable_timestamp(),
   #'basic.deliver'{consumer_tag = CTag,
			   delivery_tag = DTag,
			   redelivered = Redelivered,
			   exchange = Exchange,
			   routing_key  =RoutingKey
			  } = Method,

   {Props, Payload, ContentType, MessageId} = extract_content(Content),
   App = ensure_module_loaded(State),
   {ResponseType, Reply} = 
			process_message(ContentType, Payload, App),
   End = app_util:get_printable_timestamp(),
   {reply, Reply, State}.


handle_call(register_default_consumer, From, State) -> 
  error_logger:info_msg("Handle_call, registration of self as default consumer ~p",[From]),
 % Pid = self(),  
  AmqpParams = State#state.amqp_connection,
  error_logger:info_msg("Handle_call, sending request of self registration",[]),
  Reply = register_default_consumer(AmqpParams, From),
  {reply, Reply, State};


handle_call(subscribe, From, State) -> 
  error_logger:info_msg("Handle_call, subscription From ~p",[From]),
%  Pid = self(),  
  QueueDeclare = State#state.amqp_queue_declare,
  Queue = QueueDeclare#'queue.declare'.queue,
  Method = #'basic.consume'{queue = Queue, no_ack = false},
  error_logger:info_msg("Handle_call, sending subscription request of",[]),
  Reply =  amqp_gen_consumer:call(From, Method, []),
  {reply, Reply, State};

handle_call(unsubscribe, From, State) -> 
  error_logger:info_msg("Handle_call, unsubscription ~p",[From]),
%  Pid = self(),  
  QueueDeclare = State#state.amqp_queue_declare,
  Queue = QueueDeclare#'queue.declare'.queue,
  Method = #'basic.cancel'{},
  error_logger:info_msg("Handle_call, sending unsubscription request of",[]),
   
% amqp_channel:call(Channel, Method),


  Reply =  amqp_gen_consumer:call(From, Method, []),
  {reply, Reply, State};




handle_call({stop, {error, Why}}, From, State)->
  terminate(Why, State);

handle_call({stop, Why}, From, State)->
  terminate(Why, State);

handle_call(Request, _From, State)->
  error_logger:warn_msg("[~p]: Unknown request ~p",[?SERVER, Request]),
  {noreply, State}.  

handle_cast(Request, State) ->
  error_logger:warn_msg("[~p]: Unknown request ~p",[?SERVER, Request]),
  {noreply, State}.

handle_info(register_to_channel, State)->
  error_logger:info_msg("[~p] Delayed registering to channel",[?SERVER]),
  AmqpParams = State#state.amqp_connection,
  register_default_consumer(AmqpParams, self()),
  {noreply, State};

handle_info(timeout, State)->   
  AmqpParams = State#state.amqp_connection,
  register_default_consumer(AmqpParams, self()),  	
  {noreply, State};

handle_info({'DOWN', MRef, process, Pid, Info}, State)->
  error_logger:error_msg("Connection down, ~p ~p",[Pid, Info]),
  {noreply, State}.

handle_info({'DOWN', _MRef, process, Pid, Info}, _Len, State)->
  error_logger:error_msg("Connection down, ~p ~p",[Pid, Info]),
  {noreply, State}.

terminate(Reason, State) ->
%  error_logger:info_msg("[~p] Termination ~p",[?SERVER, Reason]),
  io:format("[~p] Termination ~p",[?SERVER, Reason]),
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

-spec ensure_module_loaded(#state{})-> {atom(), atom()}.
ensure_module_loaded(State)->
  {Mod, Loaded} = (State#state.app_env)#app_env.transform_module,
  R = ensure_load(Mod, Loaded),
  #app_env{transform_module = R}.
 
-spec ensure_load(atom(), trye|false)-> {ok, loaded} | {error, term()}.
ensure_load(M, loaded) -> {M, loaded};
ensure_load(Mod, _) when is_atom(Mod)-> 
  case app_util:ensure_loaded(Mod) of 
  	{ok, loaded} -> {Mod, loaded};
	{error, _} -> {Mod, not_loaded}
  end.

process_message(chat,Payload, Module)->
  Message = Module:new(Payload),
  process_message(Message);

process_message(undefined, Payload, State)->
  {cannot_process_message, undefined};

process_message(ContentType, Payload, State)->
  {cannot_process_message, ContentType}.

process_message(Payload) ->
  error_logger:info_msg("Sending to rest api", [?SERVER]).    
