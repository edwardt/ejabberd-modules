-ifndef(CHAT_MESSAGE_HRL).
-define(CHAT_MESSAGE_HRL, true).
-record(chat_message, {
		from ::binary(),
		to  ::binary(),
		brandId  ::binary(),
		type ::binary(), 
		format ::binary(),
		subject ::binary(), 
		body ::binary(), 
		thread ::binary(),
		time_stamp ::binary()}).


-export_records([chat_message]).


-endif.
