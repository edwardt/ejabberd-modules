-module(user_presence_srv).
-behaviour(gen_server).

-export([list_online/1,
		list_online/2,
		list_online_count/1,
		list_online_count/2,
		list_all_online/1,
		list_all_online/2]).

-export([ping/0]).

-export([start/0, stop/0]).
-export([start_link/1]).

-export([init/1, init/0,
		 handle_call/3,
		 handle_cast/2,
		 handle_info/2, 
		 terminate/2, 
		 code_change/3]).

-include_lib("user_webpresence.hrl").

-define(SERVER, ?MODULE).
-define(COPY_TYPE, disc_copies).

-define(ConfPath,"conf").
-define(ConfFile, "spark_user_presence.config").

-record(state,{
        cluster_node,
	      refresh_interval = -1, 
	      last_check
}).

-record(session, {
	sid,
	usr,
	us,
	priority,
	info
}).

-type state() :: #state{}.

start_link(Args)->
  gen_server:start_link({local, ?SERVER}, ?MODULE, Args ,[]).
   
init()->
  init([{?ConfPath, ?ConfFile}]).

init([{Path, File}])->
  Start = app_util:os_now(),
  error_logger:info_msg("Initiating ~p with config ~p ~p", [?SERVER, Path, File]),
  {ok, [ConfList]} = app_config_util:load_config(Path,File),
  {ok, Interval} = app_config_util:config_val(refresh_interval, ConfList,-1),
  {ok, Cluster} = app_config_util:config_val(cluster_node, ConfList,undefined),
  ok = create_user_webpresence(),
  erlang:send_after(Interval, self(), {query_all_online}),

  End = app_util:os_now(),
  error_logger:info_msg("Done Initiation ~p with config ~p ~p", [?SERVER, Path, File]),
  error_logger:info_msg("Done Initiation ~p Start ~p End ~p", [?SERVER, Start, End]),
  {ok, #state{cluster_info = Cluster, 
       refresh_interval = Interval,
       last_check=End}}.

start()->
   gen_server:call(?SERVER, start).

stop()->
 	gen_server:call(?SERVER, stop).

ping()->
	gen_server:call(?SERVER, ping).

sync_session_from_cluster()->
  gen_server:call(?SERVER, sync_session_from_cluster).

list_online(UserId) ->
	gen_server:call(?SERVER,{list_online, UserId}).

list_online(UserId, Since) ->
	gen_server:call(?SERVER,{list_online, UserId, Since}).

list_all_online(Since) ->
	list_all_online(call, Since).

list_all_online(Type, Since) when is_function(Type) ->
	gen_server:Type(?SERVER,{list_all_count, Since}).

list_online_count(Since)->
	list_online_count(call, Since).

list_online_count(Type, Since) when is_function(Type) ->
	gen_server:Type(?SERVER,{list_online_count, Since}).

handle_call({list_online, UserId}, _From, State)->
  OnlineUsers = user_with_active_session(UserId),
  Reply = transform(OnlineUsers),
  {reply, Reply, State};

handle_call({list_online, UserId, Since}, _From, State)->
  OnlineUsers = user_with_active_session(UserId, Since),
  Reply = transform(OnlineUsers),
  {reply, Reply, State};

handle_call({list_all_count, Since}, _From, State)->
  OnlineUsers = all_users_with_active_session(Since),
  Reply = transform(OnlineUsers),
  {reply, Reply, State};

handle_call({list_online_count, Since}, _From, State)->
  Reply= get_active_users_count(),
  {ok, Reply, State};

handle_call(sync_session_from_cluster, _From, State)->
  Reply= user_presence_db:join_as_slave(State#state.cluster_info, [session]), 
  {ok, Reply, State};

handle_call(ping, _From, State) ->
  {reply, pong, State};

handle_call(stop, _From, State) ->
  {stop, normal, stopped, State};

handle_call(_Request, _From, State) ->
  Reply = {error, function_clause},
  {reply, Reply, State}.

-spec handle_cast(tuple(), state()) -> {noreply, state()}.
handle_cast(Info, State) ->
  erlang:display(Info),
  {noreply, State}.

handle_info({query_all_online}, State)->
  ok = set_user_webpresence(),
  erlang:send_after(State#state.refresh_interval,
  	 self(), {query_all_online}),
  {noreply, State};

handle_info({heartbeat}, State)-> 
  {noreply, ok};
handle_info(_Info, State) ->
  {noreply, State}.

-spec handle_info(tuple(), pid(), state()) -> {ok, state()}.
handle_info(stop, _From, State)->
  terminate(normal, State).

terminate(_Reason, _State)->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

get_active_users_count() ->
  mnesia:table_info(session, size).

set_user_webpresence()->
   Users = mnesia:dirty_select(
      session,
      [{#session{us = '$1', _ = '_'},
    [],
    ['$1']}]),
    lists:map(fun(U) -> update_web_presence(U) end, Users).

read_session_from_ejabberd()->
  traverse_table_and_show(session).

traverse_table_and_show(Iterator, Table_name) when is_function(Iterator) ->
     case mnesia:is_transaction() of
        true -> mnesia:foldl(Iterator,[],Table_name);
        false -> 
            Exec = fun({Fun,Tab}) -> mnesia:foldl(Fun, [],Tab) end,
            mnesia:activity(transaction,
              Exec,[{Iterator,Table_name}],
              mnesia_frag)
    end.   
traverse_table_and_show(Table_name)->
    Iterator = set_user_webpresence(),
    traverse_table_and_show(Iterator, Table_name).

create_user_webpresence()->
  Start = app_util:os_now(),
  Schema = node(),
  Ret = case mnesia:create_schema([Schema]) of
  	ok ->
  		ok = app_util:start_app(mnesia),
      error_logger:info_msg("Create user_presence table", []),

  		{atomic, ok} = mnesia:create_table(user_webpresence,
  							[{ram_copies, [node()]},
  							{type, set},
  							{attribute, record_info(fields, user_webpresence)},
  							{index, [memberid]}
  							]
  			), 
  		R = mnesia:add_table_index(user_webpresence, memberid),
      error_logger:info_msg("Created table user_webpresence table with {atomic, ok} index for user_presence table status ~p", [R]),
      R;
  	{error,{S, {already_exists, S}}} -> 
        error_logger:info_msg("Failure to create_schema: ~p", [{S, {already_exists, S}}]),
        %ok = should_delete_schema(Schema),
        ok = app_util:start_app(mnesia);
    Else ->
        error_logger:info_msg("Failure to create_schema: ~p", [Else]),
        ok = app_util:start_app(mnesia)
  end,
  End = app_util:os_now(),
  error_logger:info_msg("Create user_presence table ~p Start ~p End ~p", [?SERVER, Start, End]),
  Ret.

should_delete_schema(Schema) ->
  error_logger:info_msg("Delete schema ~p", [Schema]),
  catch(mnesia:stop()),
  %app_util:stop_app(mnesia),
   ok = mnesia:delete_schema([Schema]),
  % error_logger:info_msg("Deleted schema ~p ", [Ret]),
  ok.

user_with_active_session(Jid) ->
  user_with_active_session(Jid, 0).

user_with_active_session(Jid, Since) ->
  Ret = case mnesia:dirty_read({user_webpresence, Jid}) of
  	 [] -> nothing;
  	 [{user_webpresence, Jid , _, online, Last }] when Since >= Last
  	   -> {Jid, online};
  	 _ -> {Jid, not_found}
  end.
all_users_with_active_session(Since) ->
   all_users_with_active_session(session, Since).

all_users_with_active_session(Table, Since) ->
  FilterFor = fun(Table)->
    qlc:eval(
      [X || X <- mnesia:table(Table), X#user_webpresence.token > Since]
    )
  end.
  
transform(nothing) ->[];
transform([]) -> [];
transform(OnlineUsers) ->
  OnlineUsers.

dirty_get_us_list() ->
    Users = mnesia:dirty_select(
      session,
      [{#session{us = '$1', _ = '_'},
    [],
    ['$1']}]),
    lists:map(fun(U)-> update_web_presence(U) end, Users).

update_web_presence(User) ->
  [MemberId, BrandId] = get_login_data(User),
  Token = generate_token(),
  mnesia:dirty_write({user_webpresence, MemberId, BrandId, online, Token}),
  ok.

get_login_data(User)->
   [].

generate_token() ->
   R = app_util:os_now(),
   calendar:datetime_to_gregorian_seconds(R).
