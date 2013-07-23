-module(spark_amqp_session).
-behaviour(gen_server).

-include_lib("chat_message.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-export([
         stop/0,
         establish/0,
         tear_down/0,
         list_active/0,
         ping/0]).

-export([publish/3]).

-export([start_link/0, start_link/1]).

-export([
  init/0,
  init/1, 
  handle_call/3,
  handle_cast/2,
  handle_info/2, 
  terminate/2,
  code_change/3,
  test/0
]).

-define(ConfPath,"conf").
-define(ConfFile, "spark_amqp.config").
-define(SERVER, ?MODULE).

-record(state, {
    name = <<"">>, 
    amqp_exchange,
    amqp_queue_declare,
    amqp_queue_bind ,
    amqp_connection,
    message_module 
}).


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
  error_logger:info_msg("Going to publish message to rabbitMQ",[]),
  gen_server:call(?SERVER, {publish, call, Mod, Message});
publish(cast, Mod, Messages) when is_list(Messages) ->
  gen_server:call(?SERVER, {publish, cast, Mod, Messages}).

start_link()->
  start_link([{?ConfPath, ?ConfFile}]).

start_link(Args) ->
  gen_server:start_link({local, spark_amqp_session}, spark_amqp_session, Args, []).

stop()->
  gen_server:call(?SERVER, {stop, normal}).

init()->
  init([{?ConfPath, ?ConfFile}]).

init(Args) ->
  {Path, File} = Args,
  error_logger:info_msg("~p Initialization with Path ~p File ~p",[?MODULE, Path, File]),
   
  {ok, [ConfList]} = app_config_util:load_config(Path,File),

  {ok, Name} = app_config_util:config_val(amqp_name,ConfList, <<"spark_im_chat">>),
  setup_amqp(Name, ConfList).


setup_amqp(Name, ConfList)->
  {ok, Channel, AmqpParams} = channel_setup(ConfList),
  ExchangeDeclare = exchange_setup(Channel, ConfList),
  QueueDeclare = queue_setup(Channel, ConfList),
  Queue = QueueDeclare#'queue.declare'.queue,
  Exchange =  ExchangeDeclare#'exchange.declare'.exchange,
  RoutingKey = spark_rabbit_config:get_routing_key(ConfList),
  QueueBind = queue_bind(Channel, Queue, Exchange, RoutingKey),
  error_logger:info_msg("spark_amqp_session is configured",[]),
  {ok, #state{ 
    name = Name, 
    amqp_exchange = ExchangeDeclare,
    amqp_queue_declare = QueueDeclare,
    amqp_queue_bind = QueueBind,
    amqp_connection = AmqpParams
  }}.


channel_setup(ConfList)->
%  {ok, AmqpConfList} = app_config_util:config_val(amqp_connection, ConfList, []),
  AmqpParams = spark_rabbit_config:get_connection_setting(ConfList), 

%  {ok, Channel} = amqp_channel(AmqpParams),  
  
  {ok, Connection} = amqp_connection:start(AmqpParams),
  {ok, Channel} = amqp_connection:open_channel(Connection),

  {ok, Channel, AmqpParams}.

exchange_setup(Channel, ConfList)->
%  {ok, ExchangeConfList} = app_config_util:config_val(amqp_exchange, ConfList, []),
  ExchangeDeclare = spark_rabbit_config:get_exchange_setting(ConfList),
  {'exchange.declare_ok'}  = amqp_channel:call(Channel, ExchangeDeclare), 
  ExchangeDeclare.
  
queue_setup(Channel, ConfList)->
%  {ok, QueueConfList} = app_config_util:config_val(amqp_queue, ConfList, []),
  QueueDeclare = spark_rabbit_config:get_queue_setting(ConfList),
  {'queue.declare_ok', _, _, _} = amqp_channel:call(Channel, QueueDeclare),
  QueueDeclare.

queue_bind(Channel, Queue, Exchange, RoutingKey) ->
%  {ok, QueueConfList} = app_config_util:config_val(amqp_queue, ConfList, []),
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
  Reply =
  case amqp_channel(AmqpParams) of
    {ok, Channel} ->
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

handle_call(ping, _From, State) ->
  {reply, {ok, State}, State};

handle_call(stop, _From, State) ->
  {stop, normal, stopped, State};

handle_call(_Request, _From, State) ->
  {ok, ok, State}.

-spec handle_info(tuple(), pid(), #state{}) -> {ok, #state{}}.
handle_info(stop, _From, State)->
  terminate(normal, State).

-spec handle_cast(tuple(), #state{}) -> {noreply, #state{}}.
handle_cast(Info, State) ->
  erlang:display(Info),
  {noreply, State}.

-spec handle_info(atom, #state{}) -> {ok, #state{}}.
handle_info(_Info, State) ->
  {ok, State}.

-spec terminate(atom(), #state{} ) ->ok.
terminate(_Reason, _State) ->
  ok.

-spec code_change(atom(), #state{}, list()) -> {ok, #state{}}.
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

sync_send(#state{ amqp_exchange = Exchange, amqp_queue_bind= QueueBind } = State, Messages, Channel, Mod) ->
  ContentType = <<"text/binary">>,

  Routing_key = QueueBind#'queue.bind'.routing_key,
  {Mod, Loaded} = State#state.message_module,

  R = ensure_load(Mod, Loaded),
  Ret =  lists:map(
          fun(AMessage) ->
              Method = publish_fun(cast, Exchange, Routing_key, AMessage, ContentType, Mod),  
              Mod:ensure_binary(AMessage),
              amqp_channel:call(Channel, Method, AMessage)
          end ,Messages),
  error_logger:info_msg("Status of SYNC publishing messages: ~p",[Ret]),
  State#state{message_module = R}.

async_send(#state{ amqp_exchange = Exchange, amqp_queue_bind= QueueBind } = State,  Messages, Channel, Mod) ->
  ContentType = <<"text/binary">>,
  Routing_key = QueueBind#'queue.bind'.routing_key,
  {Mod, Loaded} = State#state.message_module,
  
  R = ensure_load(Mod, Loaded),
  Ret =  lists:map(
          fun(AMessage) ->
              Method = publish_fun(cast, Exchange, Routing_key, AMessage, ContentType, Mod),      
              amqp_channel:cast(Channel, Method, AMessage)
          end, Messages),
  error_logger:info_msg("Status of ASYNC casting messages: ~p",[Ret]),
  State#state{message_module = R}.

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

