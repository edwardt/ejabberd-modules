-module(user_webpresence_model).

-include_lib("user_webpresence.hrl").
-behaviour(json_rec_model).

-compile({parse_transform, exprecs}).
-export([new/1, 
	 	 rec/1,
	  	 ensure_binary/1]).
-spec new( bitstring() )-> #user_webpresence{} | undefined.
new(#user_webpresence{} = Val) -> '#new-user_webpresence'();
new(_) -> undefined.

rec(#user_webpresence{} =Value) -> Value;
rec(_) -> undefined.

-spec ensure_binary(atom() | any()) -> binary().
ensure_binary(#user_webpresence{} = Value) ->
	Json = json_rec:to_json(Value, user_webpresence_model),
    lists:flatten(mochijson2:encode(Json));
ensure_binary(Val) -> app_util:ensure_binary(Val).
