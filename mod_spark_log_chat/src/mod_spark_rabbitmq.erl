-module(mod_spark_rabbitmq).
-author(etsang@spark.net).

-behaviour(gen_mod).
-behaviour(gen_server).

-export([publish/3]).

-export([start/2, 
%	start_link/0,
	start_link/1,
	start_link/2, 
	stop/1]).

-export([
         stop/0,
         establish/0,
         tear_down/0,
         list_active/0,
         ping/0]).

-export([
	init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).

-include("ejabberd.hrl").
-include_lib("chat_message.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").


-define(ConfPath,"conf").
-define(ConfFile, "spark_amqp.config").
-define(SERVER, ?MODULE).
-define(PROCNAME, ?MODULE).

-record(state, {
    name = <<"">>, 
    amqp_exchange,
    amqp_queue_declare,
    amqp_queue_bind ,
    amqp_connection,
    app_env
}).
-record(app_env,{
    transform_module = {undefine, not_loaded},
    restart_timeout = 5000
}).

-type state() :: #state{}.

-spec start_link() -> ok | {error, term()}.
start_link()->
  start_link([{?ConfPath, ?ConfFile}]).

-spec start_link(list()) -> ok | {error, term()}.
start_link([Host, Opts]) -> start_link(Host, Opts).

-spec start_link(string(), list()) ->ok | {error, term()}.
start_link(Host, Opts)->
  ?INFO_MSG("~p gen_server starting  ~p ~p~n", [?PROCNAME, Host, Opts]),
  Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
  ensure_dependency_started(Proc),
  Pid = gen_server:start_link({local, Proc}, ?MODULE, [Host, Opts],[]),
  ?INFO_MSG("~p started with Pid ~p~n", [?PROCNAME, Pid]), 
  Pid.

-spec ensure_dependency_started(string())-> ok.
ensure_dependency_started(Proc) ->
     Apps = [syntax_tools, 
	     compiler, 
	     crypto,
	     public_key,
	     gen_server2,
	     ssl, 
	     goldrush, 
	     rabbit_common,
	     amqp_client,
		inets 
		],
  ?INFO_MSG("[~p] Going to start apps ~p", [Proc , lists:flatten(Apps)]),
  app_util:start_apps(Apps),
  %ok = lager:start(),
  ?INFO_MSG("[~p] Started depedenecies ~p", [Proc , lists:flatten(Apps)]).


-spec start(string(), list()) -> ok | {error, term()}.
start(Host, Opts) ->
    ?INFO_MSG(" ~p  ~p~n", [Host, Opts]),
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),

    ?INFO_MSG(" ~p  ~p~n", [Host, Opts]),
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    ChildSpec = {Proc,
       {?MODULE, start_link, [Host, Opts]},
       temporary,
       1000,
       worker,
       [?MODULE]},
   
    supervisor:start_child(ejabberd_sup, ChildSpec).

-spec stop(string()) -> ok.
stop(Host) ->
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    gen_server:call(Proc, stop),
    supervisor:delete_child(ejabberd_sup, Proc),
    ok.

-spec init() -> {ok, pid()} | {error, tuple()}.
init()->
  init({?ConfPath, ?ConfFile}).

-spec init([any()]) -> {ok, pid()} | {error, tuple()}.
init([Host, Opts])->
    ?INFO_MSG("Starting Module ~p PROCNAME ~p with host ~p config ~p~n", [?MODULE, ?PROCNAME, Host, Opts]),
    File = gen_mod:get_opt(conf_file, Opts, ?ConfFile),
    
    ?INFO_MSG("~p gen_server starting  ~p ~p~n", [?PROCNAME, Host, Opts]),
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    ensure_dependency_started(Proc),

    ?INFO_MSG("Starting spark_amqp_session with args ~p",[File]),
    ConfList= read_from_config({file_full_path, File}), 
    Ret = setup_amqp(ConfList),
    ?INFO_MSG("Starting spark_amqp_session started with state ~p",[Ret]),
    {ok, Ret}.

populate_table(Name, IdMap) when is_atom(Name)->
   ?INFO_MSG("Store idMap ~p into ets table", [IdMap]),
   Tab = ets:new(Name, [named_table]),
   lists:map(fun(L)-> true = ets:insert(Tab,L) end, IdMap);
populate_table(_, _)->
   {error, badarg}.   

lookup_brandid(Jid)->
   UserName = jlib:jid_to_string(Jid),
   lookup_brandid_from_user(id_map, UserName). 

lookup_brandid_from_user(Name, UserName) when is_atom(Name) ->
   [_, CommunityId] = split_composite_id(UserName),
   C = case ets:match_object(Name,{'$1',CommunityId,'$2'}) of
    	[{_,_,B}] -> B;
    	[] -> [];
	_ -> []
   end,
   ?INFO_MSG("Found BrandId ~p", [C]),
   C. 

split_composite_id(UserName) ->
   case re:split(UserName, "-") of
	[A,B] -> [A,B];
	[] -> [UserName, ""];
   	R -> [R, ""]
   end.

-spec establish() -> {ok, pid()} | {error, badarg}.
establish()-> 
  gen_server:call(?SERVER, setup).

-spec tear_down() -> ok | {error, term()}.
tear_down()-> 
  gen_server:call(?SERVER, tear_down).

-spec list_active() -> [pid()].
list_active()-> 
  gen_server:call(?SERVER, list_active).

-spec ping() -> pong.
ping()->
  gen_server :call(?SERVER, ping).

-spec test() -> {ok, passed} | {error, failed}.
test()->
  {ok, _Pid} = establish(),
  publish(call, ?MODULE, test_msg()),
  publish(cast, ?MODULE, test_msg()),
  {ok, stopped} = tear_down().

-spec publish(atom(), atom(), list()) -> ok | {error, tuple()}.
publish(call, Mod, Message) ->
  error_logger:info_msg("~p: MOD_SPARK_RABBIT Going to publish CALL message to rabbitMQ",[?SERVER]),
  gen_server:call(?SERVER, {publish, call, Mod, Message});
publish(cast, Mod, Messages) when is_list(Messages) ->
  error_logger:info_msg("~p: MOD_SPARK_RABBIT Going to publish CAST message to rabbitMQ",[?SERVER]),
  gen_server:call(?SERVER, {publish, cast, Mod, Messages}).

stop()->
  gen_server:call(?SERVER, {stop, normal}).



read_from_config({file_full_path, File})->
   {ok, [L]} = app_config_util:load_config_file(File),
   L;

read_from_config({Path, File}) ->
   {ok, [L]} = app_config_util:load_config(Path,File),
   L.

get_config_tables()->
 [amqp_connection,amqp_exchange,
  amqp_queue, app_env].

create_config_tables()->
   Tables = get_config_tables(),
   lists:map(fun(T)-> 
		T = ets:new(T, [set, named_table]),
		error_logger:info_msg("Created config table ~p",[T]) 
	     end,Tables).

populate_table({Tag, List}) when is_atom(Tag), is_list(List)->
   lists:map(fun(A)-> ets:insert(Tag, A) end, List).

setup_amqp(ConfList)->
 %[AmqpCon, Exchange, Queue, App_Env] = ConfList,
  error_logger:info_msg("~p establishing amqp connection to server",[?SERVER]),
  {ok, Channel, AmqpParams} = channel_setup(ConfList),
  ExchangeDeclare = exchange_setup(Channel, ConfList),
  QueueDeclare = queue_setup(Channel, ConfList),
  Queue = QueueDeclare#'queue.declare'.queue,
  Name =
  Exchange =  ExchangeDeclare#'exchange.declare'.exchange,
  RoutingKey = spark_rabbit_config:get_routing_key(ConfList),
  QueueBind = queue_bind(Channel, Queue, Exchange, RoutingKey),
  AppEnv = get_app_env(ConfList),
  error_logger:info_msg("spark_amqp_session is configured",[]),
  {ok, #state{ 
    name = Name, 
    amqp_exchange = ExchangeDeclare,
    amqp_queue_declare = QueueDeclare,
    amqp_queue_bind = QueueBind,
    amqp_connection = AmqpParams,
    app_env = AppEnv
  }}.

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
  
handle_call({setup}, _From, State)->
  AmqpParams = State#state.amqp_connection,
  Reply = amqp_channel(AmqpParams),
  {reply, Reply, State};

handle_call({tear_down, Pids}, From, State)->
  Reply = 
  case handle_call({list_all_active}, From, State) of
     {error, _} -> {ok, stopped};
     Pids -> lists:map(
                  fun(Pid) -> 
                    amqp_connection:close(Pid) 
                  end,
                  Pids
             )
  end,

  {reply, Reply, State};

handle_call({list_active}, From, State)->
  R1 = handle_call({list_all_active_conn}, From, State),
  R2 = handle_call({list_all_active_chan}, From, State),
  Reply = lists:concat([R1, R2]),
  {reply, Reply, State};

handle_call({list_all_active_conn}, _From, State)->
  AmqpParams = State#state.amqp_connection,
  Reply = 
  case pg2:get_local_members({AmqpParams, connection} ) of
    {error, {no_such_group, G}} -> {error, {no_such_group, G}};
    Pid -> Pid
  end,
  {reply, Reply, State};

handle_call({list_all_active_chan}, _From, State)->
  AmqpParams = State#state.amqp_connection,
  Reply = 
  case pg2:get_local_members({AmqpParams, channel} ) of
    {error, {no_such_group, G}} -> {error, {no_such_group, G}};
    Pid -> Pid
  end,
  {reply, Reply, State};

handle_call({publish, call, Mod, AMessage}, _From, State)->
 
  AmqpParams = State#state.amqp_connection,
  error_logger:info_msg("Publishing to rabbitmq using connection amqp_params: ~p",[?SERVER, AmqpParams]),
  Reply =
  case amqp_channel(AmqpParams) of
    {ok, Channel} ->
      error_logger:info_msg("[~p] Found connection ~p resuse",[?SERVER, Channel]),
      sync_send(State,  [AMessage], Channel, Mod); 
    _ ->
      State
  end,
  {reply, Reply, State};

handle_call({publish, cast, Mod, Messages}, _From, State)->
  AmqpParams = State#state.amqp_connection,
  Reply =
  case amqp_channel(AmqpParams) of
    {ok, Channel} ->
      async_send(State, Messages, Channel, Mod); 
    _ ->
      State
  end,
  {reply, Reply, State}; 

handle_call(stop, _From, State) ->
  {stop, normal, stopped, State};
handle_call(Req, _From, State) ->
  error_logger:error_msg("Unsupported Request",[Req]),
  {reply, unsupported, State}.

-spec handle_cast(atom(), state()) -> {noreply, state()}.
handle_cast(Info, State) ->
  erlang:display(Info),
  {noreply, State}.

-spec handle_info(atom(), pid(), state()) -> {ok, state()}.
handle_info(stop, _From, State)->
  terminate(normal, State).

-spec handle_info(atom(), state()) -> {ok, state()}.
handle_info(stop, State)->
  terminate(normal, State);
handle_info(Info, State) ->
  error_logger:error_msg("Unsupported Request",[Info]), 
  {ok, State}.

-spec terminate(atom(), state() ) ->ok.
terminate(_Reason, _State) ->
  ok.

-spec code_change(atom(), state(), list()) -> {ok, state()}.
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

sync_send(#state{ amqp_exchange = Exchange, amqp_queue_bind= QueueBind } = State, Messages, Channel, Mod) ->
  ContentType = <<"text/binary">>,

  Routing_key = QueueBind#'queue.bind'.routing_key,
  {Mod, Loaded} = (State#state.app_env)#app_env.transform_module,

  R = ensure_load(Mod, Loaded),
  App = #app_env{transform_module = R},
  Ret =  lists:map(
          fun(AMessage) ->
              Method = publish_fun(cast, Exchange, Routing_key, 
			AMessage, ContentType, Mod),  
              Mod:ensure_binary(AMessage),
              amqp_channel:call(Channel, Method, AMessage)
          end ,Messages),
  error_logger:info_msg("Status of SYNC publishing messages: ~p",[Ret]),
  State#state{app_env=App}.

async_send(#state{ amqp_exchange = Exchange, amqp_queue_bind= QueueBind } = State,  Messages, Channel, Mod) ->
  ContentType = <<"text/binary">>,
  Routing_key = QueueBind#'queue.bind'.routing_key,
  {Mod, Loaded} = (State#state.app_env)#app_env.transform_module,
  
  R = ensure_load(Mod, Loaded),
  App = #app_env{transform_module = R},
  Ret =  lists:map(
          fun(AMessage) ->
              Method = publish_fun(cast, Exchange, Routing_key, 	
                                   AMessage, ContentType, Mod),      
              amqp_channel:cast(Channel, Method, AMessage)
          end, Messages),
  error_logger:info_msg("Status of ASYNC casting messages: ~p",[Ret]),
  State#state{app_env=App}.

amqp_channel(AmqpParams) ->
  case maybe_new_pid({AmqpParams, connection},
                     fun() -> amqp_connection:start(AmqpParams) end) of
    {ok, Client} ->
      maybe_new_pid({AmqpParams, channel},
                    fun() -> amqp_connection:open_channel(Client) end);
    Error -> Error
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


publish_fun(CallType, Exchange,Routing_key, Message, ContentType, Mod) ->
  Mod:ensure_binary(Message),

  rabbit_farm_util:get_fun(CallType, 
      #'basic.publish'{ exchange   = Exchange,
                  routing_key = Routing_key},
      
      #amqp_msg{props = #'P_basic'{content_type = ContentType,
                  message_id=message_id()}, 
              
      payload = Message}).
-spec message_id()-> binary().
message_id()->
  uuid:uuid4().

-spec ensure_load(atom(), trye|false)-> {ok, loaded} | {error, term()}.
ensure_load(_, true) -> {ok, loaded};
ensure_load(Mod, _) when is_atom(Mod)-> 
  app_util:ensure_loaded(Mod). 

test_msg()->
  Msg1 = message_id(),
  app_util:ensure_binary(Msg1).



