-module(spark_im_mail_message_model).
-include_lib("spark_im_mail_message.hrl").
-behaviour(json_rec_model).

-compile({parse_transform, exprecs}).
-export([new/1, 
	 	 rec/1,
	  	 ensure_binary/1]).
-spec new( bitstring() )-> #spark_im_mail_message{} | undefined.
new(<<"spark_im_mail_message">>)->
   '#new-spark_im_mail_message'();
new(_)-> undefined.

rec(#spark_im_mail_message{} =Value) ->  Value;
rec(_)-> undefined.

-spec ensure_binary(atom() | any()) -> binary().
ensure_binary(#spark_im_mail_message{} = Value) ->
    Json = json_rec:to_json(Value, spark_im_mail_message_model),
    lists:flatten(mochijson2:encode(Json));
ensure_binary(Val) -> app_util:ensure_binary(Val).
