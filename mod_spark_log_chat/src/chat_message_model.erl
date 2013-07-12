-module(chat_message_model).
-include_lib("chat_message.hrl").

-behaviour(json_rec_model).

-export([new/1]).

-record(chat_message, {
		from = "" ::string(),
		from_brandId = "" ::string(),
		to = "" ::string(),
		to_brandId = "" ::string(),
		type = "chat" ::string(), 
		format = "text" ::string(),
		subject = "" ::string(), 
		body = "" ::string(), 
		thread = "" ::string(),
		time_stamp = "" ::string()}).

new(<<"chat_message">>)->
   '#chat_message'();
new(_)-> undefined.