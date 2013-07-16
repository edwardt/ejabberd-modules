-module(spark_amqp_session).
-behaviour(gen_server).

-include_lib("chat_message.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-export([
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
    exchange,
    queue_declare,
    queue_bind ,
    amqp_connection,
    message_module 
}).


-spec establish(atom()) -> {ok, pid()} | {error, badarg}.
establish()-> 
  gen_server:call(?SERVER, setup);
establish(_) -> {error, badarg}.

tear_down()-> 
  gen_server:call(?SERVER, tear_down);
tear_down(_) -> {error, badarg}.

list_active()-> 
  gen_server:call(?SERVER, list_active);
list_active(_) -> {error, badarg}.

ping()->
  gen_server :call(?SERVER, ping).

test()->
  {ok, _Pid} = establish(test),
  {ok, stopped} = tear_down(test).

publish(call, Mod, Message) ->
  gen_server:call(?SERVER, {publish, call, Mod, Message});
publish(cast, Mod, Messages) when is_list(Messages) ->
  gen_server:call(?SERVER, {publish, cast, Mod, Messages}).

start_link()->
  start_link([{?ConfPath, ?ConfFile}]).

start_link(Args) ->
  [{Path, File}] = Args,
  gen_server:start_link({local, spark_amqp_session}, spark_amqp_session, [{Path, File}], []).

init()->
  init([{?ConfPath, ?ConfFile}]).

init([{Path, File}]) ->
  {ok, [ConfList]} = app_config_util:load_config(Path,File),
  {ok, AmqpConfList} = app_config_util:get_value(amqp_connection, ConfList, []),
  {ok, ExchangeConfList} = app_config_util:get_value(amqp_exchange, ConfList, []),
  {ok, QueueConfList} = app_config_util:get_value(amqp_queue, ConfList, []),
  {ok, Name} = app_config_util:get_value(amqp_name,ConfList, <<"spark_im_chat">>),
  setup(Name, AmqpConfList, ExchangeConfList, QueueConfList).

setup(Name, AmqpConfList,ExchangeConfList,QueueConfList)->
  AmqpParams = spark_rabbit_config:get_connection_setting(AmqpConfList), 
  ExchangeDeclare = spark_rabbit_config:get_exchange_setting(ExchangeConfList),
  QueueDeclare = spark_rabbit_config:get_queue_setting(QueueConfList),
  QueueBind = spark_rabbit_config:get_queue_bind(QueueConfList),
  {ok, Channel} = amqp_channel(AmqpParams),
  {'exchange.declare_ok'}  = amqp_channel:call(Channel, ExchangeDeclare),
  {'queue.declare_ok', _, _, _} = amqp_channel:call(Channel, QueueDeclare),
  {'queue.bind_ok'}  = amqp_channel:call(Channel, QueueBind),
  {ok, #state{ 
    name = Name, 
    exchange = ExchangeDeclare,
    queue_declare = QueueDeclare,
    queue_bind = QueueBind,
    amqp_connection = AmqpParams
  }}.
  
handle_call({setup}, From, State)->
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
  AmqpParams = State#state.amqp_connection,
  Reply = 
  case pg2:get_closest_pid(ProcGroupName) of
    {error, {no_such_group, G}} -> {error, {no_such_group, G}};
    {error, {no_process, G0}} ->  {error, {no_process, G0}};
    Pid -> Pid
  end,
  {reply, Reply, State};

handle_call({list_all_active_conn, Group}, From, State)->
  AmqpParams = State#state.amqp_connection,
  {AmqpParams, connection} 
  Reply = 
  case pg2:get_local_members({AmqpParams, connection} ) of
    {error, {no_such_group, G}} -> {error, {no_such_group, G}};
    Pid -> Pid
  end,
  {reply, Reply, State};

handle_call({list_all_active_chan, Group}, From, State)->
  AmqpParams = State#state.amqp_connection,
  Reply = 
  case pg2:get_local_members({AmqpParams, channel} ) of
    {error, {no_such_group, G}} -> {error, {no_such_group, G}};
    Pid -> Pid
  end,
  {reply, Reply, State};

handle_call({publish, call, Mod, AMessage}, From, State)->
  AmqpParams = State#state.amqp_connection,
  Reply =
  case amqp_channel(AmqpParams) of
    {ok, Channel} ->
      sync_send(#state{ name = Name, exchange = Exchange } = State,  [AMessage], Channel, Mod); 
    _ ->
      State
  end,
  {reply, Reply, State};

handle_call({publish, cast, Mod, Messages}, From, State)->
  AmqpParams = State#state.amqp_connection,
  Reply =
  case amqp_channel(AmqpParams) of
    {ok, Channel} ->
      async_send(#state{ name = Name, exchange = Exchange } = State, Messages, Channel, Mod); 
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

sync_send(#state{ name = Name, exchange = Exchange } = State, Messages, Channel, Mod) ->
  ContentType = <<"text/binary">>,
  Fun = publish_fun(call, Exchange, RoutingKey, Message, ContentType, Mod),
  {Mod, Loaded} = State#state.message_module,
  R = ensure_load(Mod, Loaded),
  Ret =  lists:map(
          fun(Message) ->
              Method = Fun(Message),
              Mod:ensure_binary(Message),
              amqp_channel:call(Method, Message)
          end ,Messages),
  State#state{message_module = R}.

async_send(#state{ name = Name, exchange = Exchange } = State,  Messages, Channel, Mod) ->
  ContentType = <<"text/binary">>,
  {Mod, Loaded} = #state.message_module,
  R = ensure_load(Mod, Loaded),
  Fun = publish_fun(cast, Exchange, Message, ContentType, Mod),
  Ret =  lists:map(
          fun(Message) ->
              Method = Fun(Message),             
              amqp_channel:cast(Method, Message)
          end, Messages),
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


publish_fun(CallType, Exchange, Message, ContentType, Mod) ->
  Mod:ensure_binary(Message),
  Routing_key = Exchange#exchange.routing_key,
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
ensure_load(Mod, true) -> {ok, loaded};
ensure_load(Mod, _) when is_atom(Mod)-> 
  case code:ensure_loaded(Mod) of
      {module, Mod} -> {ok, true};
      E -> {error, E}
  end.


