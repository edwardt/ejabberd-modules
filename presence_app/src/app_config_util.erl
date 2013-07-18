-module(app_config_util).

-export([
		cwd/0,
		config_val/3,
		load_config/0,
		load_config/1,
		load_config/2]).

-define(CONFPATH,"conf").

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

-spec config_val(atom(), list(), any()) -> any().
config_val(Key, Params, Default) -> {ok, proplists:get_value(Key, Params, Default)}.
