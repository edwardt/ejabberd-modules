-module(rabbit_farm_util).
-export([ensure_binary/1, 
	     get_fun/2,
		 get_fun/3]).

-export([cwd/0, 
		os_now/0,
		timespan/2,
		load_config/0,
		load_config/1,
		load_config/2]).
-include_lib("amqp_client/include/amqp_client.hrl").
-define(CONFPATH,"conf").

-spec get_fun(cast, atom())-> fun().
get_fun(cast, Method)->
	fun(Channel)->
			amqp_channel:cast(Channel, Method)
	end;
get_fun(call, Method)->
	fun(Channel)->
			amqp_channel:call(Channel, Method)
	end.

-spec get_fun(cast, atom(), term())-> fun().
get_fun(cast, Method, Content)->
	fun(Channel)->
			amqp_channel:cast(Channel, Method, Content)
	end;
get_fun(call, Method, Content)->
	fun(Channel)->
			amqp_channel:call(Channel, Method, Content)
	end.
-spec ensure_binary(any())-> bitstring().
ensure_binary(Value) -> app_util:ensure_binary(Value).

-spec load_config()-> list().
load_config()->
  {ok, ConfDir}= cwd(),
  load_config(ConfDir, "spark_consumer.config").

-spec load_config(string())-> list().
load_config(File) ->
  {ok, ConfDir}= cwd(),
  load_config(ConfDir,File).

-spec load_config(string(), string())-> list().
load_config(ConfDir,File) when is_list(ConfDir), 
			  is_list(File)->
  FileFullPath = lists:concat([ConfDir,"/", File]),
  error_logger:info_msg("Loading config: ~p",[FileFullPath]),
  {ok, [ConfList]}= file:consult(FileFullPath),
  {ok, [ConfList]}.

-spec cwd()-> {ok, string()}.
cwd()->
  {ok, Cwd} = file:get_cwd(),
  {ok, lists:concat([Cwd,"/",?CONFPATH])}.

-spec os_now() -> calendar:datetime1970().
os_now()-> app_util:os_now().

-spec timespan( calendar:datetime1970(), calendar:datetime1970())-> calendar:datetime1970().
timespan(A,B)-> app_util:timespan(A,B).
