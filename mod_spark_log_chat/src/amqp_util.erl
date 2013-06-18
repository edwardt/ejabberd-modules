%% @doc
%% Refactor the common utility function into a sperate file
%% model after  videlalvaro/rmq_patterns
%% @end.
-module(amqp_util).
-author('etsang@spark.net').

-include_lib("amqp_client.hrl").
%-include_lib("rabbit_framing.hrl").

-export([get_connection_setting/1,
	 setup_connection/0,
	 teardown_connection/2,
	 declare_exchange/3,
	 declare_queue/3,
	 publish_msg/3
%	 consume_msg/2
	]).


get_connection_setting(Host)->
	#amqp_params_network{
	username           = get_username(Host),
        password           = get_password(Host),
        virtual_host       = get_virtual_host(Host),
        host               = get_host(Host),
        port               = get_port(Host),
        channel_max        = get_channel_max(Host),
        frame_max          = get_frame_max(Host),
        heartbeat          = get_heartbeat(Host),
        connection_timeout = get_connection_timeout(Host),
        ssl_options        = get_auth_mechanism(Host),
        auth_mechanisms    = get_auth_mechanism(Host),
        client_properties  = get_client_properties(Host),
        socket_options     = get_channel_max(Host)					 
	}.

setup_connection()->
  {ok, Connection} = amqp_connection:start(get_connection_setting(Host)),
  {ok, Channel} = amqp_connection:open_channel(Connection),
  {ok, ExchangePrefix} = get_exchangeprefix(Host),
  {ok, KeyPrefix} = get_keyprefix(Host),
  {ok, Connection, Channel, ExchangePrefix, KeyPrefix}.

teardown_connection(Channel, Connection)->
  amqp_channel:close(Channel),
  amqp_connection:close(Connection).

declare_exchange(Connection, Channel, Exchange) ->
  {Name, Type, Durable} = Exchange,
  #'exchange.declare_ok'{}=amqp_channel:call(Channel,
			  #'exchange.declare'{
			    exchange = Name,
			    type = Type,
			    durable = Durable}),
  ok.

declare_queue(Channel, Exchange, RoutingKey)->
  {Name, Exclusive, Auto_Delete} = QueueName,
  #'queue.declare_ok'{queue = ControlQ}
	= amqp_channel:call(Channel, 
			 #'queue.declare'{
			   exclusive = Exclusive,
			   auto_delete = Auto_Delete}),
  QueueBind = #'queue.bind'{queue = ControlQ, exchange = Exchange,
			    routing_key= RoutingKey},

  #'queue.bin_ok'{} = amqp_channel:call(Channel, QueueBind),

  #'basic_consume_ok'{consumer_tag=ControlTag}  
	= amqo_channel:subscribe(Channel, #'basic.consume'{
				queue=ControlQ,
				no_ack=false}, self()),
  {ok, ControlTag}.


publish_msg(Exchange, Message, RoutingKey)->
  {ok, Connection, Channel, ExchangePrefix, KeyPrefix} = setup_connection(),
  Exchange_Full = concat_exchange(ExchangePrefix, Exchange),
  Publish = #'basic.publish'{exchange = Exchange_Full, routing_key=RoutingKey},
  amqp_channel:call(Channel, Publish, #amqp_msg{payload = serialize(Message) }), 
  teardown_connection(Channel, Connection).


%consume_msg()->
  




serialize(Message)->
  term_to_binary(Message).

concat_exchange(ExchangePrefix, Exchange)->
  <<ExchangePrefix/binary, Exchange/binary>>.







%% -----------------------seperate this out ---------------
%% TODO: generate securely deterministically 
get_username(Host)->
  try_get_option(Host, username, <<"sparknet">>). 

%% TODO: generate securely deterministically 
get_password(Host)->
  try_get_option(Host, password, <<"sparknet">>). 

get_virtual_host(Host)->
  try_get_option(Host, virtual_host, <<"/chat.spark.net">>). 

get_host(Host)->
  try_get_option(Host, host,"localhost"). 

get_port(Host)->
  try_get_option(Host, host, undefined). 

get_channel_max(Host)->
  try_get_option(Host, channel_max, 0). 

get_frame_max(Host)->
  try_get_option(Host, framemax, 0). 

get_heartbeat(Host)->
  try_get_option(Host, heartbeat, 0). 

get_connection_timeout(Host)->
  try_get_option(Host, virtual_host, 5). 

get_ssl_options(Host)->
  try_get_option(Host, ssl_options, none).

get_auth_mechanism(Host)->
  try_get_option(Host, auth_mechanism, 
          [fun amqp_auth_mechanisms:plain/3,
           fun amqp_auth_mechanisms:amqplain/3]).

get_client_properties(Host)->
  try_get_option(Host, client_properties, []). 

get_exchangeprefix(Host)->
  try_get_option(Host,exchangeprefix, <<"">>).
get_keyprefix(Host)->
  try_get_option(Host,keyprefix, <<"">>).


try_get_option(Host, OptionName, DefaultValue) ->
    case gen_mod:is_loaded(Host, ?MODULE) of
	true -> ok;
	_ -> throw({module_must_be_started_in_vhost, ?MODULE, Host})
    end,
    gen_mod:get_module_opt(Host, ?MODULE, OptionName, DefaultValue).






