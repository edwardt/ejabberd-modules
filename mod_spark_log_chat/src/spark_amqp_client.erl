-module(spark_amqp_client).
-behaviour(gen_event).

-include_lib("amqp_client/include/amqp_client.hrl").

-export([
  init/1, 
  handle_call/2, 
  handle_event/2, 
  handle_info/2, 
  terminate/2,
  code_change/3,
  test/0
]).

-record(state, {
  name,
  level,
  exchange,
  params
}).

init(Params) ->
  
  Name = config_val(name, Params, ?MODULE),  
  Level = config_val(level, Params, debug),
  Exchange = config_val(exchange, Params, list_to_binary(atom_to_list(?MODULE))),
  
  AmqpParams = P
  
  {ok, Channel} = amqp_channel(AmqpParams),
  #'exchange.declare_ok'{} = amqp_channel:call(Channel, #'exchange.declare'{ exchange = Exchange, type = <<"topic">> }),
  
  {ok, #state{ 
    name = Name, 
    level = Level, 
    exchange = Exchange,
    params = AmqpParams
  }}.

handle_call({set_loglevel, Level}, #state{ name = _Name } = State) ->
  % io:format("Changed loglevel of ~s to ~p~n", [Name, Level]),
  {ok, ok, State#state{ level=lager_util:level_to_num(Level) }};
    
handle_call(get_loglevel, #state{ level = Level } = State) ->
  {ok, Level, State};
    
handle_call(_Request, State) ->
  {ok, ok, State}.

handle_event({log, Dest, Level, {Date, Time}, Message}, #state{ name = Name, level = L} = State) when Level > L ->
  case lists:member({lager_amqp_backend, Name}, Dest) of
    true ->
      {ok, log(Level, Date, Time, Message, State)};
    false ->
      {ok, State}
  end;

handle_event({log, Level, {Date, Time}, Message}, #state{ level = L } = State) when Level =< L->
  {ok, log(Level, Date, Time, Message, State)};
  
handle_event(_Event, State) ->
  {ok, State}.

handle_info(_Info, State) ->
  {ok, State};

handle_info(timeout,State) ->
  {noreply, State, hibernate};

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

log(Level, Date, Time, Message, #state{params = AmqpParams } = State) ->
  case amqp_channel(AmqpParams) of
    {ok, Channel} ->
      send(State, Level, [Date, " ", Time, " ", Message], Channel);
    _ ->
      State
  end.

send(#state{ name = Name, exchange = Exchange } = State, Level, Message, Channel) ->
  RkPrefix = atom_to_list(lager_util:num_to_level(Level)),
  RoutingKey =  list_to_binary( case Name of
                                  [] ->
                                    RkPrefix;
                                  Name ->
                                    string:join([RkPrefix, Name], ".")
                                end
                              ),
  Publish = #'basic.publish'{ exchange = Exchange, routing_key = RoutingKey },
  Props = #'P_basic'{ content_type = <<"text/plain">> },
  Body = list_to_binary(lists:flatten(Message)),
  Msg = #amqp_msg{ payload = Body, props = Props },

  % io:format("message: ~p~n", [Msg]),
  amqp_channel:cast(Channel, Publish, Msg),

  State.

amqp_channel(AmqpParams) ->
  case maybe_new_pid({AmqpParams, connection},
                     fun() -> amqp_connection:start(AmqpParams) end) of
    {ok, Client} ->
      maybe_new_pid({AmqpParams, channel},
                    fun() -> amqp_connection:open_channel(Client) end);
    Error ->
      Error
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
        Error ->
          Error
      end;
    Pid ->
      {ok, Pid}
  end.
  

  
