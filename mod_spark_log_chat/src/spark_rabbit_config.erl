-module(spark_rabbit_config).
-export([
	get_connection_setting/1,
	get_exchange_setting/1,
	get_queue_setting/1,
 	get_routing_key/1,
	get_queue_bind/3,
	get_consumer/1

]).

-include_lib("amqp_client/include/amqp_client.hrl").

-spec get_connection_setting(list()) ->#'amqp_params_network'{}.
get_connection_setting(ConfFList) ->
      {ok, ConfList} = app_config_util:config_val(amqp_connection, ConfFList, []),
	UserName    = proplists:get_value(username, ConfList,<<"spark">>),
	Password    = proplists:get_value(password,ConfList,<<"spark">>),
	%true = password:is_secure(Password),
	VirtualHost = proplists:get_value(virtual_host,ConfList,<<"/">>),
	Host        = proplists:get_value(host, ConfList, "localhost"),
	Port        = proplists:get_value(port,ConfList,5672),

	R = #amqp_params_network{
				username     = rabbit_farm_util:ensure_binary(UserName),
				password     = Password,
				virtual_host = rabbit_farm_util:ensure_binary(VirtualHost),
				host         = Host,
				port         = Port
				}, 
       print_amqp(R),

       R.
-spec get_exchange_setting(list())-> #'exchange.declare'{}.
get_exchange_setting(ConfList)->
  {ok, FeedOpt} = app_config_util:config_val(amqp_exchange, ConfList, []),
	Ticket       = proplists:get_value(ticket,FeedOpt,0),
	Exchange     = proplists:get_value(exchange,FeedOpt),
	Type         = proplists:get_value(type,FeedOpt,<<"direct">>),
	Passive      = proplists:get_value(passive,FeedOpt,false),
	Durable      = proplists:get_value(durable,FeedOpt,false),
	AutoDelete   = proplists:get_value(auto_delete,FeedOpt,false),
	Internal     = proplists:get_value(internal,FeedOpt,false),
	NoWait       = proplists:get_value(nowait,FeedOpt,false),
	Arguments    = proplists:get_value(arguments,FeedOpt,[]),
	#'exchange.declare'{
				ticket      = Ticket,
				exchange    = rabbit_farm_util:ensure_binary(Exchange),
				type        = rabbit_farm_util:ensure_binary(Type),
				passive     = Passive,
				durable     = Durable,
				auto_delete = AutoDelete,
				internal    = Internal,
				nowait      = NoWait,
				arguments   = Arguments
				}.

-spec get_queue_setting(list())-> #'queue.declare'{}.
get_queue_setting(ConfList)->
     {ok, FeedOpt} = app_config_util:config_val(amqp_queue, ConfList, []),
	QTicket		 = proplists:get_value(qticket, FeedOpt, 0),
	Queue 		 = proplists:get_value(queue, FeedOpt, <<"">>),
	QPassive	 = proplists:get_value(qpassive, FeedOpt, false),
	QDurable	 = proplists:get_value(qdurable, FeedOpt, false),
	QExclusive	 = proplists:get_value(qexclusive, FeedOpt, false),
	QAutoDelete	 = proplists:get_value(qauto_delete, FeedOpt, false),
	QNoWait 	 = proplists:get_value(qnowait, FeedOpt, false),
	QArguments	 = proplists:get_value(qarguments, FeedOpt, []),

	#'queue.declare'{
			   ticket = QTicket,
			   queue = Queue,
			   passive     = QPassive,
			   durable     = QDurable,
			   auto_delete = QAutoDelete,
			   exclusive   = QExclusive,
			   nowait      = QNoWait,
			   arguments = QArguments}.	

-spec get_routing_key(list()) -> binary().	
get_routing_key(ConfList)->
  {ok, QueueConfList} = app_config_util:config_val(amqp_queue, ConfList, []),
   proplists:get_value(routing_key,QueueConfList). 
  
-spec get_queue_bind(binary(), binary(), binary())->#'queue.bind'{}.
get_queue_bind(Queue, Exchange, RoutingKey)->
   #'queue.bind'{
		queue = Queue,
		exchange = Exchange,
		routing_key = RoutingKey
		}.

-spec get_consumer(list())-> #'basic.consume'{}.
get_consumer(FeedOpt) ->
	Consumer_tag = proplists:get_value(consumer_tag, FeedOpt, <<"">>),
	Queue 		 = proplists:get_value(queue, FeedOpt, <<"">>),
	Ticket 		 = proplists:get_value(ticket, FeedOpt, 0),
	NoLocal		= proplists:get_value(no_local, FeedOpt, false),
	No_ack		= proplists:get_value(no_ack, FeedOpt, false),
	Exclusive	= proplists:get_value(exclusive, FeedOpt, false),
	Nowait      = proplists:get_value(nowait,FeedOpt,false),
	Arguments 	= proplists:get_value(arguments,FeedOpt,[]),
	#'basic.consume'{
		ticket = Ticket,
		queue = Queue,
		no_local = NoLocal,
		no_ack = No_ack,
		exclusive = Exclusive,
		nowait = Nowait,
		consumer_tag = Consumer_tag,
		arguments= Arguments
	}.

print_amqp(#amqp_params_network{} = R) ->
   error_logger:info_msg("Username: ~p",[R#amqp_params_network.username] ),
   error_logger:info_msg("Password: ~p",[R#amqp_params_network.password] ),
   error_logger:info_msg("VirtualHost: ~p",[R#amqp_params_network.virtual_host] ),
   error_logger:info_msg("Host: ~p",[R#amqp_params_network.host] ),
   error_logger:info_msg("Port: ~p",[R#amqp_params_network.port] ).
