-module(chat_message_model).
-include_lib("chat_message.hrl").
-behaviour(json_rec_model).

-compile({parse_transform, exprecs}).
-export([new/1, 
	 rec/1]).

new(<<"chat_message">>)->
   '#new-chat_message'();
new(_)-> undefined.

rec(#chat_message{} =Value) ->  Value;
rec(_)-> undefined.
