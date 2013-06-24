-ifndef(MOD_SPARK_LOG_CHAT_HRL).
-define(MOD_SPARK_LOG_CHAT_HRL, true).

-include_lib("amqp_client/include/amqp_client.hrl").

-record(config, {
		 path		    = ?DEFAULT_PATH, 
		 format		    = ?DEFAULT_FORMAT,
		 idMap		    = [],
		 host		     = <<"">>,
		 connection_timeout  = ?HIBERNATE_TIMEOUT,
	  	 name = ?DEFAULT_NAME,
    		 exchange = ?DEFAULT_EXCHANGE, 
		 queue=?DEFAULT_QUEUE,
		 amqp_params = #amqp_params_network {}
}).

-record(chat_msg, {
		 sid = [],
		 subject = [],
		 from_mid = [],
		 from_bid = [],
		 to_mid = [],
	  	 to_bid = [],
		 body = []
}).


-endif.
