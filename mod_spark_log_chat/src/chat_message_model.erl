-module(chat_message_model).
%-include_lib("chat_message.hrl").

-behaviour(json_rec_model).
-compile([parse_transform, exprecs]).
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


-export_records([chat_message]).


new(<<"chat_message">>)->
   '#new-chat_message'();
new(_)-> undefined.