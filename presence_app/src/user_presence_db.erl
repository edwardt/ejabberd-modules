-module(mod_presence_db).
-behaviour(gen_server).

-export([reach_node/1,
		 join/1,
		 join_as_master/1,
		 sync_node/1,
		 list_change_since/2
		]).

-export([ping/0]).

-export([start/0, stop/0]).
-export([start_link/1]).

-export([init/1,
		handle_call/3,
		handle_cast/2,
		handle_info/2,
		code_change/3,
		terminate/2]).

%-define(USER_TABLE, ).
-define(SERVER, ?MODULE).
-define(COPY_TYPE, disc_copies).

start()->
   gen_server:call(?SERVER, start).

stop()->
 	gen_server:call(?SERVER, stop).

ping()->
	gen_server:call(?SERVER, ping).

reach_node(Name) ->
  gen_server:call(?SERVER, {reach_node, Name}).

join(Name) -> join_as_slave(Name).

join_as_slave(Name) ->
  gen_server:call(?SERVER, {join_as_slave, Name}).

join_as_master(Name)->
  gen_server:call(?SERVER, {join_as_master, Name}).

sync_node(Name) ->
  gen_server:call(?SERVER, {sync_node, Name}).

list_change_since(TableName, Since) ->
  gen_server:call(?SERVER, {list_change_since, TableName, Since}).

handle_call({reach_node, Name}, From, State) when is_atom(Name) ->
  Reply = 
  case net_adm:ping(Name) of
  	'pong' -> {ok, reachable};
  	_ -> {error, unreachable}
  end,
  {ok, Reply, State};

handle_call({join_as_slave, Name}, From, State) when is_atom(Name)->
  prepare_sync(Name),
  Reply = post_sync(Name),
  {ok, Reply, State};

handle_call({join_as_master, Name}, From, State) when is_atom(Name)->
  prepare_sync(Name),
  sync_node(Name),
  Reply = post_sync(Name),
  {ok, Reply, State};

handle_call({sync_node, Name}, From, State) when is_atom(Name)->
  Reply = sync_node(Name),
  {ok, Reply, State};

handle_call({list_change_since, TableName, Since}, From, State) when is_atom(TableName)->
  
  {ok, Reply, State};

handle_call(ping, _From, State) ->
  {reply, {ok, 'pong'}, State};

handle_call(stop, _From, State) ->
  {stop, normal, stopped, State};

handle_call(_Request, _From, State) ->
    Reply = {error, function_clause},
    {reply, Reply, State}.

handle_cast(Info, State) ->
  erlang:display(Info),
  {noreply, State}.

-spec handle_info(tuple(), state()) -> {ok, state()}.
handle_info(_Info, State) ->
  {ok, State}.

-spec handle_info(tuple(), pid(), state()) -> {ok, state()}.
handle_info(stop, _From, State)->
  terminate(normal, State).

-spec terminate(atom(), state()) -> ok.
terminate(Reason, _State) ->
   ok.

code_change(_OldVsn, State, _Extra)->
   {ok, State}.

prepare_sync(Name) ->
  prepare_sync(Name, ?COPY_TYPE).  
prepare_sync(Name, Type) ->
  mnesia:stop(),
  mnesia:delete_schema([node()]),
  mnesia:start(),
  mnesia:change_config(extra_db_nodes,[Name]),
  mnesia:change_table_copy_type(schema, node(), Type).

post_sync(Name) when is_atom(Name) ->
  app_util:stop_app(Name),
  app_util:start_app(Name).

sync_node(NodeName) ->
  [{Tb, mnesia:add_table_copy(Tb, node(), Type)} 
   || {Tb, [{NodeName, Type}]} <- [{T, mnesia:table_info(T, where_to_commit)}
   || T <- mnesia:system_info(tables)]].
