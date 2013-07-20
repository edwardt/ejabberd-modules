-ifndef(ONLINE_USER_JSON_HRL).
-define(ONLINE_USER_JSON_HRL, true).

-record(online_user_json, {
	count :: integer(),
	token :: pos_integer()
}).

-export_records([online_user_json]).
-endif.