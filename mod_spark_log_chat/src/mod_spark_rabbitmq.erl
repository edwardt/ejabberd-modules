-module(mod_spark_rabbitmq).
-author(etsang@spark.net).

-behaviour(gen_mod).
-behaviour(gen_server).

-export([establish/0 ,publish/3]).

-export([start/2,
	start_link/2, 

	stop/1]).

-export([
	init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).

-include("ejabberd.hrl").

-define(ConfPath,"conf").
-define(ConfFile, "spark_amqp.config").
-define(SERVER, ?MODULE).
-define(PROCNAME, ?MODULE).

-record(state, {
}).

-type state() :: #state{}.

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
		%ets,
		goldrush, 
		rabbit_common,
		amqp_client,
		inets 
		],
  ?INFO_MSG("[~p] Going to start apps ~p", [?PROCNAME, lists:flatten(Apps)]),
  app_util:start_apps(Apps),
  %ok = lager:start(),
  ?INFO_MSG("[~p] Started depedenecies ~p", [?PROCNAME, lists:flatten(Apps)]).

-spec start(string(), list()) -> ok | {error, term()}.
start(Host, Opts) ->
    ?INFO_MSG(" ~p  ~p~n", [Host, Opts]),
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),

    ?INFO_MSG(" ~p  ~p~n", [Host, Opts]),
    ChildSpec = {Proc,
       {mod_spark_rabbitmq_sup, start_link, [Host, Opts]},
       permanent,
       infinity,
       supervisor,
       [mod_spark_rabbitmq_sup]},
    case supervisor:start_child(ejabberd_sup, ChildSpec) of
        {ok, _Pid} -> ok;
        {ok, _Pid, _Info} ->ok;
        {error, {already_started, _PidOther}} -> ok;
        {error, Error} ->
            {'EXIT', {start_child_error, Error}}
    end.

-spec stop(string()) -> ok.
stop(Host) ->
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    gen_server:call(Proc, stop),
    supervisor:delete_child(ejabberd_sup, Proc),
    ok.

-spec init([any()]) -> {ok, pid()} | {error, tuple()}.
init([Host, Opts])->
    ?INFO_MSG("Starting Module ~p PROCNAME ~p with host ~p config ~p~n", [?MODULE, ?PROCNAME, Host, Opts]),
    File = gen_mod:get_opt(conf_file, Opts, ?ConfFile),
    
    ?INFO_MSG("~p gen_server starting  ~p ~p~n", [?PROCNAME, Host, Opts]),
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    ensure_dependency_started(Proc),

    ?INFO_MSG("Starting spark_amqp_session with args ~p",[File]),
    Ret = spark_amqp_session:init({file_full_path, File}), 
    ?INFO_MSG("Starting spark_amqp_session started with state ~p",[Ret]),
    {ok, #state{}}.



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
   [MemberId, CommunityId] = split_composite_id(UserName),
   C = case ets:match_object(Name,{'$1',CommunityId,'$2'}) of
    	[{_,_,B}] -> B;
    	[] -> [];
	R -> []
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

-spec publish(atom(), atom(), list()) -> ok | {error, tuple()}.
publish(call, Mod, Message) ->
  error_logger:info_msg("~p: MOD_SPARK_RABBIT Going to publish CALL message to rabbitMQ",[?SERVER]),
  gen_server:call(?SERVER, {publish, call, Mod, Message});
publish(cast, Mod, Messages) when is_list(Messages) ->
  error_logger:info_msg("~p: MOD_SPARK_RABBIT Going to publish CAST message to rabbitMQ",[?SERVER]),
  gen_server:call(?SERVER, {publish, cast, Mod, Messages}).

handle_call({setup}, _From, State)->
  Reply = spark_amqp_session:establish(),
  {reply, Reply, State};

handle_call({publish, call, Mod, AMessage}, _From, State)->
  error_logger:info_msg("~p Calling spark_amqp_session:publish/3",[?SERVER]), 
  Reply = spark_amqp_session:publish(call, Mod, AMessage),
  {reply, Reply, State};

handle_call({publish, cast, Mod, Messages}, _From, State)->
  Reply = spark_amqp_session:publish(cast, Mod, Messages),
  {reply, Reply, State}; 

handle_call(Req, _From, State) ->
  error_logger:error_msg("Unsupported Request",[Req]),
  {reply, unsupported, State}.

-spec handle_cast(tuple(), state()) -> {noreply, state()}.
handle_cast(Info, State) ->
  erlang:display(Info),
  {noreply, State}.


-spec handle_info(tuple(), pid(), state()) -> {ok, state()}.
handle_info(stop, _From, State)->
  terminate(normal, State).

-spec handle_info(tuple(), state()) -> {ok, state()}.
handle_info(Info, State) ->
  error_logger:error_msg("Unsupported Request",[Info]), 
  {ok, State}.

-spec terminate(atom(), state()) -> ok.
terminate(Reason, _State) ->
  ?INFO_MSG("~p has been terminated ~p ", [?PROCNAME, Reason]),
  ok.

-spec code_change(atom, state(), list()) -> ok.
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.






