-module(spark_amqp_session).
-behaviour(gen_server).

-include_lib("chat_message.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-export([start/0, stop/0, 
         establish/1,
         tear_down/1,
         list_active/1,
         list_all_active/0,
         ping/0,
         test/0]).

-export([publish/2]).

-export([start_link/1, start_link/2]).

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
    params 
}).


-spec establish(atom()) -> {ok, pid()} | {error, badarg}.
establish(ProcGroupName) when is_atom(ProcGroupName)-> 
  gen_server:call(?SERVER, setup, ProcGroupName);
establish(_) -> {error, badarg}.

tear_down(ProcGroupName) when is_atom(ProcGroupName)-> 
  gen_server:call(?SERVER, tear_down, ProcGroupName);
tear_down(_) -> {error, badarg}.

list_active(ProcGroupName) when is_atom(ProcGroupName)-> 
  gen_server:call(?SERVER, list_active, ProcGroupName);
list_active(_) -> {error, badarg}.

list_all_active() -> 
  gen_server:call(?SERVER, list_all_active);

ping()->
  gen_server :call(?SERVER, ping).

test()->
  {ok, Pid} = establish(test),
  {ok, stopped} = tear_down(test).

publish(call, Message) ->
  gen_server:call(?SERVER, {publish, call, Module, Message});
publish(cast, Messages) when is_list(Messages) ->
  gen_server:call(?SERVER, {publish, cast, Module, Messages}).

init()->
  init([?ConfPath, ?ConfFile]).

init(Args) ->
  [{Path, File}] = Args,
  {ok, [ConfList]} = app_config_util:load_config(Path,File),
  {ok, AmqpConfList} = app_config_util:get_value(amqp_connection, ConfList, []),
  {ok, ExchangeConfList} = app_config_util:get_value(amqp_exchange, ConfList, []),
  {ok, QueueConfList} = app_config_util:get_value(amqp_queue, ConfList, []),
  setup(AmqpConfList,ExchangeConfList,QueueConfList).

setup(AmqpConfList,ExchangeConfList,QueueConfList)->
  AmqpParams = spark_rabbit_config:get_connection_setting(AmqpConfList), 
  ExchangeDeclare = spark_rabbit_config:get_exchange_setting(ExchangeConfList),
  QueueDeclare = spark_rabbit_config:get_queue_setting(QueueConfList),
  QueueBind = spark_rabbit_config:get_queue_bind(ConfList),
  {ok, Channel} = amqp_channel(AmqpParams),
  {'exchange.declare_ok'}  = amqp_channel:call(Channel, ExchangeDeclare),
  {'queue.declare_ok', _, _, _} = amqp_channel:call(Channel, QueueDeclare),
  {'queue.bind_ok'}  = amqp_channel:call(Channel, QueueBind),
  {ok, #state{ 
    name = Name, 
    exchange = Exchange,
    queue_declare = QueueDeclare,
    queue_bind = QueueBind,
    params = AmqpParams
  }}.
  
handle_call({setup, ProcGroupName}, From, State)->
  AmqpParams = State#state.params,
  Reply = amqp_channel(ProcGroupName, AmqpParam),
  {reply, Reply, State}.

handle_call({tear_down, ProcGroupName, Pids}, From, State)->
  Reply =
  case handle_call({list_all_active, Group}, From, State) of
     {error, _} -> {ok, stopped};
     Pids -> lists:map(
                  fun(Pid) -> 
                    amqp_connection:close(Pid) 
                  end,
                  Pids
             ),
  end,

  {reply, Reply, State}.

handle_call({list_active, ProcGroupName}, From, State)->
  Reply = 
  case pg2:get_closest_pid(Group) of
    {error, {no_such_group, G}} -> {error, {no_such_group, G}};
    {error, {no_process, G0}} ->  {error, {no_process, G0}};
    Pid -> Pid
  end,
  {reply, Reply, State}.

handle_call({list_all_active, Group}, From, State)->
  Reply = 
  case pg2:get_local_members(Group) of
    {error, {no_such_group, G}} -> {error, {no_such_group, G}};
    Pid -> Pid
  end,
  {reply, Reply, State}.

handle_call({publish, call, Module, AMessage}, From, State)->
  AmqpParams = State#state.amqp_connection,
  Reply =
  case amqp_channel(AmqpParams) of
    {ok, Channel} ->
      sync_send(#state{ name = Name, exchange = Exchange } = State, Level, [AMessage], Channel, Module); 
    _ ->
      State
  end.
  {reply, Reply, State};

handle_call({publish, cast, Module, Messages}, From, State)->
  AmqpParams = State#state.amqp_connection,
  Reply =
  case amqp_channel(AmqpParams) of
    {ok, Channel} ->
      async_send(#state{ name = Name, exchange = Exchange } = State, Level, Messages, Channel, Module); 
    _ ->
      State
  end.
  {reply, Reply, State}.  

handle_call(ping, _From, State) ->
  {reply, {ok, State}, State};

handle_call(stop, _From, State) ->
  {stop, normal, stopped, State};

handle_call(_Request, _From, State) ->
  {ok, ok, State}.

-spec handle_info(tuple(), pid(), state()) -> {ok, state()}.
handle_info(stop, _From, State)->
  terminate(normal, State).

-spec handle_cast(tuple(), state()) -> {noreply, state()}.
handle_cast(Info, State) ->
  erlang:display(Info),
  {noreply, State}.



-spec handle_info(atom, state()) -> {ok, state()}.
handle_info(_Info, State) ->
  {ok, State}.

-spec terminate(atom(), state() ) ->ok.
terminate(_Reason, _State) ->
  ok.

-spec code_change(atom(), state(), list()) -> {ok, state()}
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

sync_send(#state{ name = Name, exchange = Exchange } = State, Level, Messages, Channel, Module) ->
  Fun = publish_fun(call, Exchange, RoutingKey, Message, ContentType, Module)
  Ret =  lists:map(
          fun(Message) ->
              Method = Fun(Message),
              Module:ensure_binary(Message),
              amqp_channel:call(Method, Message)
          end <- Messages),

  State.

async_send(#state{ name = Name, exchange = Exchange } = State, Level, Messages, Channel, Module) ->
  ContentType = <<"text/binary">>,
  Fun = publish_fun(cast, Exchange, Message, ContentType, Module),
  Ret =  lists:map(
          fun(Message) ->
              Method = Fun(Message),
              Module:ensure_binary(Message),
              amqp_channel:cast(Method, Message)
          end <- Messages),
  State.

-spec (config_val(atom(), list(), any())) -> any().
config_val(C, Params, Default) -> proplists:get_value(Key, List, Default).

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


publish_fun(CallType, Exchange, Message, ContentType) ->
  rabbit_farm_util:get_fun(CallType, 
      #'basic.publish'{ exchange   = Exchange,
                  routing_key = Exchange.routing_key},
      
      #amqp_msg{props = #'P_basic'{content_type = ContentType,
                  message_id=message_id()}, 
              
      payload = Message}).

message_id()->
  uuid:uuid4().


