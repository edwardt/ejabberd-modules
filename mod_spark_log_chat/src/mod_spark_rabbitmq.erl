-module(mod_spark_rabbitmq).
-author(etsang@spark.net).

-behaviour(gen_mod).
-behaviour(gen_server).

-compile([parse_transform, lager_transform]).

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

-include_lib("lager/include/lager.hrl").

-define(ConfPath,"conf").
-define(ConfFile, "spark_amqp.config").
-define(SERVER, ?MODULE).
-define(PROCNAME, ?MODULE).

-record(state, {
    name = <<"">>, 
    ctag = <<"">>,
    amqp_exchange,
    amqp_queue_declare,
    amqp_queue_bind ,
    amqp_connection,
    app_env
}).
-record(app_env,{
    transform_module = {undefined, not_loaded},
    publisher_confirm = false,
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
%  Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
  ensure_dependency_started(?SERVER),
%  Pid = gen_server:start_link({local, Proc}, ?MODULE, [Host, Opts],[]),
  Pid = gen_server:start_link({local, ?SERVER}, ?MODULE, [Host, Opts],[]),
  ?INFO_MSG("~p started with Pid ~p~n", [?PROCNAME, Pid]), 
  Pid.

-spec ensure_dependency_started(string())-> ok.
ensure_dependency_started(Proc) ->
     Apps = [syntax_tools, 
	     compiler, 
	     crypto,
	     public_key,
	  %   gen_server2,
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
    ChildSpec = {?SERVER,
       {?MODULE, start_link, [Host, Opts]},
       temporary,
       1000,
       worker,
       [?MODULE]},
   
    supervisor:start_child(ejabberd_sup, ChildSpec).

-spec stop(string()) -> ok.
stop(Host) ->
%    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    gen_server:call(?SERVER, stop),
    supervisor:delete_child(ejabberd_sup, ?SERVER),
    ok.

-spec init() -> {ok, pid()} | {error, tuple()}.
init()->
  init({?ConfPath, ?ConfFile}).

-spec init([any()]) -> {ok, pid()} | {error, tuple()}.
init([Host, Opts])->
    ?INFO_MSG("Starting Module ~p PROCNAME ~p with host ~p config ~p~n", [?MODULE, ?PROCNAME, Host, Opts]),
    File = gen_mod:get_opt(conf_file, Opts, ?ConfFile),
    
    ?INFO_MSG("~p gen_server starting  ~p ~p~n", [?PROCNAME, Host, Opts]),
%    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    ensure_dependency_started(?SERVER),

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
%  Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
  error_logger:info_msg("~p: MOD_SPARK_RABBIT Going to publish CALL message to rabbitMQ",[?SERVER]),
  gen_server:call(?SERVER, {publish, call, Mod, Message});
publish(cast, Mod, Messages) when is_list(Messages) ->
%  Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
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

setup_rabbitmq__runtime_env(ConfList)->
  {ok, Channel, AmqpParams} = channel_setup(ConfList),
  AppEnv = get_app_env(ConfList),
  {ok, Ret} = register_channel_confirm(AppEnv, Channel),
  ExchangeDeclare = exchange_setup(Channel, ConfList),
  QueueDeclare = queue_setup(Channel, ConfList),
  ok = register_default_handler(Channel, self()),
  {ok,  Channel, AmqpParams, ExchangeDeclare, QueueDeclare, AppEnv}.

register_channel_confirm(#app_env{publisher_confirm = Confirm}
			 = AppEnv, Channel) ->
  
  R = case Confirm of 
      [] -> will_not_confirm;
      Else ->  {'confirm.select_ok'} =  
                    amqp_channel:call(Channel, Else), 
               will_confirm_delivery      
  end,
  {ok, R}.   

setup_amqp(ConfList)->
  error_logger:info_msg("~p establishing amqp connection to server",[?SERVER]),
  {ok,  Channel, AmqpParams, ExchangeDeclare, QueueDeclare, AppEnv} =
	setup_rabbitmq__runtime_env(ConfList),
  Queue = QueueDeclare#'queue.declare'.queue,
  Name =
  Exchange =  ExchangeDeclare#'exchange.declare'.exchange,
  RoutingKey = spark_rabbit_config:get_routing_key(ConfList),
  QueueBind = queue_bind(Channel, Queue, Exchange, RoutingKey),
  error_logger:info_msg("spark_amqp_session is configured",[]),
  #state{ 
    name = Name, 
    amqp_exchange = ExchangeDeclare,
    amqp_queue_declare = QueueDeclare,
    amqp_queue_bind = QueueBind,
    amqp_connection = AmqpParams,
    app_env = AppEnv
  }.

-spec get_app_env(list()) -> #app_env{}.	
get_app_env(ConfList)->
  error_logger:info_msg("Reading application setting",[]),
  {ok, AppConfList} = app_config_util:config_val(app_env, ConfList, []),
  TransformMod = proplists:get_value(transform_module,AppConfList),
  Restart_timeout = proplists:get_value(restart_timeout,AppConfList),
  Publisher_confirm = proplists:get_value(publisher_confirm,AppConfList),
  IsLoaded = ensure_load(TransformMod, false),
  Confirm = case Publisher_confirm of 
 	true -> #'confirm.select'{nowait = false};
	false -> []
  end,
  error_logger:info_msg("Retrieved application setting",[]),
  #app_env{
    transform_module = IsLoaded,
    publisher_confirm = Confirm,
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
  error_logger:info_msg("Establishing exchange",[]),
  ExchangeDeclare = spark_rabbit_config:get_exchange_setting(ConfList),
  {'exchange.declare_ok'}  = amqp_channel:call(Channel, ExchangeDeclare), 
  error_logger:info_msg("Exchange established"),
  ExchangeDeclare.
  
queue_setup(Channel, ConfList)->
  error_logger:info_msg("Declaring Queue",[]),
  QueueDeclare = spark_rabbit_config:get_queue_setting(ConfList),
  {'queue.declare_ok', _, _, _} = amqp_channel:call(Channel, QueueDeclare),
  
  error_logger:info_msg("Declared Queue",[]),
  QueueDeclare.

queue_bind(Channel, Queue, Exchange, RoutingKey) ->
  error_logger:info_msg("Binding Queue",[]),

  QueueBind = spark_rabbit_config:get_queue_bind(Queue, Exchange, RoutingKey),
  {'queue.bind_ok'}  = amqp_channel:call(Channel, QueueBind),
  error_logger:info_msg("Bound Queue",[]),

  QueueBind.
  
register_default_handler(Channel, Pid) ->
  R = amqp_channel:register_return_handler(Channel, Pid),
  error_logger:info_msg("Register ~p as a default handler for unrourtable message: ~p",[self(), R]),
  ok.
  
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
                      catch(amqp_connection:close(Pid)) 
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
  error_logger:info_msg("[~p] Handling_call Publishing CALL to rabbitmq using connection amqp_params",[?SERVER]),
  AmqpParams = State#state.amqp_connection,
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
  error_logger:info_msg("[~p] Handling_call Publishing CAST to rabbitmq using connection amqp_params",[?SERVER]),
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

handle_info(#'basic.return'{reply_code = ReplyCode, reply_text = << "unroutable" >>, exchange = Exchange, routing_key = RouteKey}, _From, State) ->
  error_logger:error_msg("Undeliverable messages. status: ~p, from: ~p with key: ~p",[ReplyCode, Exchange, RouteKey]),
  {noreply, State};
handle_info(stop, _From, State)->
  terminate(normal, State).

-spec handle_info(atom(), state()) -> {ok, state()}.
handle_info(stop, State)->
  terminate(normal, State);
handle_info(Info, State) ->
  error_logger:error_msg("Unsupported Request",[Info]), 
  {noreply, State}.

-spec terminate(atom(), state() ) ->ok.
terminate(_Reason, _State) ->
  ok.

-spec code_change(atom(), state(), list()) -> {ok, state()}.
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

sync_send(#state{ amqp_exchange = Exchange, amqp_queue_bind= QueueBind } = State, Messages, Channel, Mod) ->
  ContentType = <<"text/binary">>,
  error_logger:info_msg("[~p] Sync SEND to ~p encode",[?SERVER, Mod]),
  Routing_key = QueueBind#'queue.bind'.routing_key,
  App = ensure_module_loaded(State),
  error_logger:info_msg("[~p] Sync SEND Encoding module ~p is loaded",[?SERVER, Mod]),

  Ret =  lists:map(
          fun(AMessage) ->
  	      error_logger:info_msg("[~p] Sync SEND to Channel ~p Method ~p Encoded message",[?SERVER, Channel, Mod]),
	      Ret0 = publish_message_sync(Mod, Channel, Exchange, Routing_key, ContentType, AMessage),
	      error_logger:info_msg("[~p] Sync SENT to Channel ~p Ret ~p",[?SERVER, Channel, Ret0])

          end ,Messages),
  error_logger:info_msg("Status of SYNC publishing messages: ~p",[Ret]),
  State#state{app_env=App}.

async_send(#state{ amqp_exchange = Exchange, amqp_queue_bind= QueueBind } = State,  Messages, Channel, Mod) ->
  ContentType = <<"text/binary">>,
  Routing_key = QueueBind#'queue.bind'.routing_key,
  App = ensure_module_loaded(State),
  Ret =  lists:map(
          fun(AMessage) ->
  	      error_logger:info_msg("[~p] ASYNC CAST to Channel ~p Method ~p Encoded message",[?SERVER, Channel, Mod]),
	      Ret0 = publish_message_async(Mod, Channel, Exchange, Routing_key, ContentType, AMessage),
  	      error_logger:info_msg("[~p] ASYNC CASTED to Channel ~p Ret ~p",[?SERVER, Channel, Ret0])
          end, Messages),
  error_logger:info_msg("Status of ASYNC casting messages: ~p",[Ret]),
  State#state{app_env=App}.

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

publish_message_sync(Mod, Channel, Exchange, Routing_key, CententType, AMessage)->
   publish_message(call, Mod, Channel, Exchange, Routing_key, CententType, AMessage).

publish_message_async(Mod, Channel, Exchange, Routing_key, ContentType, AMessage)->
   publish_message(cast, Mod, Channel, Exchange, Routing_key, ContentType, AMessage).

publish_message(Func, Mod, Channel, Exchange, Routing_key, ContentType, AMessage)->
    Message = Mod:ensure_binary(AMessage),
    Method = create_publish_method(Exchange, Routing_key),
    Payload = create_publish_payload(ContentType, Message),
    Ret0 = amqp_channel:Func(Channel, Method, Payload).
  
create_publish_method(Exchange, Routing_Key)->
       ExchangeName = Exchange#'exchange.declare'.exchange,
       #'basic.publish'{ exchange   = ExchangeName,
                  	 routing_key = Routing_Key}.
 
create_publish_payload(ContentType, Message)->
      #amqp_msg{props = #'P_basic'{content_type = ContentType,
                message_id=message_id()}, payload = Message}.  


-spec ack(atom(), pid(), integer()) -> ok | {error, noproc | closing}.
ack(Func, Channel, DeliveryTag) ->
   Method = #'basic.ack'{delivery_tag = DeliveryTag, multiple = false},
   try amqp_channel:Func(Channel, Method) of
       ok      -> ok;
       closing -> {error, closing}
   catch
   	_:{noproc, _} -> {error, noproc}
   end.



-spec message_id()-> binary().
message_id()->
  uuid:uuid4().

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

test_msg()->
  Msg1 = message_id(),
  app_util:ensure_binary(Msg1).



