-module(spark_rabbit_consumer_chat).

-behaviour(gen_server).

%% API
-export([
    start/0,
    start/2,
    stop/0,
    stop/1,
    subscribe/0,
    unsubscribe/0,
    subscribe/1,
    unsubscribe/1,
    send/2,
    get_all_msg/1,
    get_users/1]).

%% gen_server callbacks

-export([start_link/0, start_link/1, start_link/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
    terminate/2, code_change/3]).

%% 
-record(state, {msgList = []}).

-define(SERVER, spark_rabbit_consumer).
-define(CONF_PATH, "conf").
-define(CONF_AMQP, "spark_amqp.config").
-define(CONF_REST, "spark_rest.config").

start_link()->
	Args = [{?CONF_PATH, ?CONF_AMQP, ?CONF_REST}],
	start_link(?SERVER, Args).
	
start()-> start_link().

start_link(Name, Args)->
    error_logger:info_msg("Register ~p cluster with name ~p~n",
    [?SERVER, Name]),
    gen_server_cluster:start(Name, ?SERVER, Args, []).
   
start_link(Args)-> 
    start_link(?SERVER, Args).
  	
start(Name, Args) ->
    start_link(Name, Args).
   
send(Name, Text) ->
    gen_server:call({global, Name}, {send, {Name, node(), Text}}).

get_all_msg(Name) ->
    io:format("All messages of ~p:~n", [Name]),
    MsgList = gen_server:call({global, Name}, get_all_msg),
    F = fun({Node, Text}) ->
        io:format("[~p]: ~p~n", [Node, Text])
    end,
    lists:foreach(F, MsgList),
    ok.

get_users(Name) ->
    {GlobalNode, LocalNodeList} = gen_server_cluster:get_all_server_nodes(Name),
    [GlobalNode | LocalNodeList].
    
subscribe()-> subscribe(?SERVER).
    
subscribe(Name)->
    gen_server:call({global, ?SERVER}, subscribe, [Name]).

unsubscribe() -> unsubscribe(?SERVER).    
unsubscribe(Name)->
  	gen_server:call({global, ?SERVER}, unsubscribe, [Name]).

stop()->
	stop(?SERVER).
	
stop(Name) ->
    gen_server:call({global, Name}, stop).

init(Args) ->
    error_logger:info_msg("Initialization of ~p with ~p~n",
    	[?SERVER, Args]),
    {ok, #state{}}.
    

handle_call({send, {Name, Node, Text}}, _From, _State) ->
    F = fun(State) ->
        error_logger:info_msg("[~p,~p]: ~p~n", [Name, Node, Text]),
        NewMsgList = [{Node, Text} | State#state.msgList],
        State#state{msgList = NewMsgList}
    end,
    {reply, sent, F};

handle_call(get_all_msg, _From, State) ->
    List = lists:reverse(State#state.msgList),
    {reply, List, State};

handle_call(stop, _From, State) ->
    {stop, normalStop, State};

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
