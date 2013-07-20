-module(web_pres_model).
-behaviour(json_rec_model).
-include_lib("web_pres.hrl").

-compile({parse_transform, exprecs}).
-export_records([web_pres]).

-export([new/1, 
	 	 rec/1,
	  	 ensure_binary/1]).
-spec new( bitstring() )-> #web_pres_model{} | undefined.
new(#web_pres_model{} = Val) -> '#new-web_pres_model'();
new(_) -> undefined.

rec(#web_pres_model{} =Value) -> Value;
rec(_) -> undefined.

-spec ensure_binary(atom() | any()) -> binary().
ensure_binary(#web_pres_model{} = Value) ->
	Json = json_rec:to_json(Value, web_pres_model),
    lists:flatten(mochijson2:encode(Json));
ensure_binary(Val) -> app_util:ensure_binary(Val).
