-module(mod_presence_srv).
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

-export([
		 handle_call/3,
		 handle_cast/2,
		 handle_info/2, 
		 terminate/2, 
		 code_change/3]).


-define(SERVER, ?MODULE).
-define(COPY_TYPE, disc_copies).
-define(EPOCH, 63249771661). %Phantom start of time {{2004,04,21},{13,01,01}} in sec.

start()->
   gen_server:call(?SERVER, start).

stop()->
 	gen_server:call(?SERVER, stop).

ping()->
	gen_server:call(?SERVER, ping).

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
  Reply = 
  {reply, Reply, State}.

handle_call({list_online, UserId, Since}, _From, State)->
  Reply = 
  {reply, Reply, State}.

handle_call({list_all_count, Since}, _From, State)->
  Reply = 
  {reply, Reply, State}.

handle_call({list_online_count, Since}, _From, State)->
  Reply = 
  {reply, Reply, State}.

handle_call(ping, _From, State) ->
  {reply, {ok, State}, State};

handle_call(stop, _From, State) ->
  {stop, normal, stopped, State};

handle_call(_Request, _From, State) ->
    Reply = {error, function_clause},
    {reply, Reply, State}.

-spec handle_cast(tuple(), state()) -> {noreply, state()}.
handle_cast(Info, State) ->
	erlang:display(Info),
    {noreply, State}.

-spec handle_info(tuple(), state()) -> {ok, state()}.
handle_info(_Info, State) ->
  {ok, State}.

-spec handle_info(tuple(), pid(), state()) -> {ok, state()}.
handle_info(stop, _From, State)->
  terminate(normal, State).

terminate(_Reason, _State)->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

query_online()->

  {ok, UserList, Count}.


