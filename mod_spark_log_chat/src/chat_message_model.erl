-module(chat_message_model).
-include_lib("chat_message.hrl").

-behaviour(json_rec_model).

-export([new/1]).
new(<<"chat_message">>)->
   '#chat_message'();
new(_)-> undefined.