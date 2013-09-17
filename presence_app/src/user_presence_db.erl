-module(user_presence_db).
-behaviour(gen_server).

-export([reach_node/1, get_cluster_head/0,
		 join/1, join/2,
		 join_as_slave/0,
     	 join_as_master/1,
		 sync_node/1
		]).

-export([ping/0]).

-export([start/0, stop/0]).
-export([start_link/1]).

-export([init/1, init/0,
		handle_call/3,
		handle_cast/2,
		handle_info/2,
		code_change/3,
		terminate/2]).

-include_lib("user_webpresence.hrl").

-define(SERVER, ?MODULE).
-define(COPY_TYPE, ram_copies).
-define(TAB_TIMEOUT, 1000).
-define(ConfPath,"priv").
-define(ConfFile, "spark_ejabberd_cluster.config").

-record(state,{
        cluster_head,
        reachable = 0
}).

-type state() :: #state{}.

start_link() -> start_link([]).
start_link(Args)->
  R = gen_server:start_link({local, ?SERVER}, ?MODULE, Args ,[]),
 % erlang:send_after(Interval, self(), {join_as_slave}),
  R.

start()->
  start_link().

stop()->
 	gen_server:call(?SERVER, stop).

init()->
  init({?ConfPath, ?ConfFile}).

init(Args)->
  error_logger:info_msg("Initiating user_presence_db ~p with config ~p", [?SERVER, Args]),
  Start = app_util:os_now(),
  {Path, File} = Args,
  error_logger:info_msg("Initiating db ~p with config ~p ~p", [?SERVER, Path, File]),
  {ok, [ConfList]} = app_config_util:load_config(Path,File),
  error_logger:info_msg("~p config values ~p", [?SERVER, ConfList]),
  {ok, Cluster} = app_config_util:config_val(cluster_head, ConfList,undefined),
  error_logger:info_msg("~p Going to talk to ~p", [?SERVER, Cluster]),
  {ok, #state{cluster_head = Cluster}};

init(_Args)->
  init([{?ConfPath, ?ConfFile}]).

ping()->
	gen_server:call(?SERVER, ping).

get_cluster_head()->
   gen_server:call(?SERVER, get_cluster_head).

reach_node(Name) ->
  gen_server:call(?SERVER, {reach_node, Name}).

join(Name) -> join_as_slave(Name).

join(Name, Tab) -> join_as_slave(Name, Tab).

join_as_slave()-> 
  gen_server:call(?SERVER, {join_as_slave}).

join_as_slave(Name) ->
  gen_server:call(?SERVER, {join_as_slave, Name}).

join_as_slave(Name, Tabs) ->
  gen_server:call(?SERVER, {join_as_slave, Name, Tabs}).  

join_as_master(Name)->
  gen_server:call(?SERVER, {join_as_master, Name}).

join_as_master(Name, Tab)->
  gen_server:call(?SERVER, {join_as_master, Name, Tab}).

sync_node(Name) ->
  gen_server:call(?SERVER, {sync_node, Name}).

sync_node_session(Name) ->
  gen_server:call(?SERVER, {sync_node_session, Name}).

handle_call(get_cluster_head, From, State) ->
  Reply = State#state.cluster_head,
  {reply, Reply, State};

handle_call({reach_node, Name}, From, State) when is_atom(Name) ->
  Reply = is_node_reachable(Name),
  {reply, Reply, State};


handle_call({join_as_slave}, From, State) ->
  NodeName = State#state.cluster_head,
  {ok, reachable} = is_node_reachable(NodeName),
  Reply = prepare_sync(NodeName),
  NewState = #state{cluster_head = NodeName, 
	            reachable = State#state.reachable +1},

  {reply, Reply, NewState}; 


handle_call({join_as_slave, Name}, From, State) when is_atom(Name)->

  {ok, reachable} = is_node_reachable(Name),
  Reply = prepare_sync(Name),
  NewState = #state{cluster_head = Name, 
	            reachable = State#state.reachable +1},

  {reply, Reply, NewState}; 


handle_call({join_as_slave, Name, Tabs}, From, State) when is_atom(Name)->

  {ok, reachable} = is_node_reachable(Name),
  Reply = prepare_sync(Name, Tabs, ?COPY_TYPE),
  NewState = #state{cluster_head = Name, 
	            reachable = State#state.reachable +1},

  {reply, Reply, NewState}; 


handle_call({join_as_slave, Name, Tabs}, From, State) when is_atom(Name)->

  {ok, reachable} = is_node_reachable(Name),
  prepare_sync(Name),
  Reply = post_sync(Name),
  NewState = #state{cluster_head = Name, 
	            reachable = State#state.reachable +1},

  {reply, Reply, NewState}; 



handle_call({join_as_master, Name}, From, State) when is_atom(Name)->

  {ok, reachable} = is_node_reachable(Name),
  prepare_sync(Name),
  Reply = sync_node_all_tables(Name),
  NewState = #state{cluster_head = Name, 
	            reachable = State#state.reachable +1},

  {reply, Reply, NewState}; 


handle_call({join_as_master, Name, Tabs}, From, State) when is_atom(Name)->

  {ok, reachable} = is_node_reachable(Name),
  prepare_sync(Name),
  Reply = sync_node_some_tables(Name, Tabs),
  NewState = #state{cluster_head = Name, 
	            reachable = State#state.reachable +1},

  {reply, Reply, NewState}; 

handle_call({sync_node_all, Name}, From, State) when is_atom(Name)->
  Reply = sync_node_all_tables(Name),
  {reply, Reply, State};

handle_call({sync_node_some_tables, Name, Tabs}, From, State) when is_atom(Name)->
  Reply = sync_node_some_tables(Name, Tabs),
  {reply, Reply, State};

handle_call({sync_node_session_table, Name}, From, State) when is_atom(Name)->
  handle_call({sync_node_some_tables, Name, [session]}, From, State);

handle_call(ping, _From, State) ->
  {reply, {ok, 'pong'}, State};

handle_call(stop, _From, State) ->
  Reply = terminate(normal, State),
  {reply, normal, stopped, State};

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
terminate(Reason, State) ->
  error_logger:info_msg("user_presence_db at ~p terminated",[node()]), 
  ok.

code_change(_OldVsn, State, _Extra)->
   {ok, State}.

prepare_sync(TargetName) ->
  prepare_sync(TargetName,[schema], ?COPY_TYPE).  

prepare_sync(TargetName, Type) ->
  prepare_sync(TargetName, ?COPY_TYPE).

prepare_sync(TargetName, Tabs, Type) -> 
  error_logger:info_msg("Stopping mnesia delete schema ~p",[TargetName, Type]),
  mnesia:stop(),
  mnesia:delete_schema([node()]),
  mnesia:start(),
  mnesia:change_config(extra_db_nodes,[TargetName]),
  error_logger:info_msg("Added ~p as part of extra db nodes. Type ~p ",[TargetName, Type]),
  lists:map(
    fun(Tab)-> 
      mnesia:change_table_copy_type(Tab, node(), Type)
    end
    , Tabs).

post_sync(Name) when is_atom(Name) ->
  app_util:stop_app(Name),
  R = app_util:start_app(Name),
  error_logger:info_msg("Done post_sync",[]),
  R.

sync_node_all_tables(NodeName) ->
  sync_node_some_tables(NodeName, mnesia:system_info(tables)).

sync_node_some_tables(NodeName, Tables) ->
  [{Tb, fun(Tb, Type) -> 
              {atomic, ok} = mnesia:add_table_copy(Tb, node(), Type),
              error_logger:info_msg("Added table ~p",[Tb])
        end} 
   || {Tb, [{NodeName, Type}]} <- [{T, mnesia:table_info(T, where_to_commit)}
   || T <- Tables]],
  ok = mnesia:wait_for_tables(Tables, ?TAB_TIMEOUT), ok.
 
is_node_reachable('pong') -> {ok, reachable}; 
is_node_reachable('pang') -> {error, unreachable};
is_node_reachable(Name) when is_atom(Name) ->
   error_logger:info_msg("Going to ping node ~p",[Name]),
   is_node_reachable(net_adm:ping(Name)).
