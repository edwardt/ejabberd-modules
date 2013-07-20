-ifndef(ONLINE_USER_JSON_HRL).
-define(ONLINE_USER_JSON_HRL, true).

-record(online_userjson, {
	count :: bitstring(),
	token :: pos_integer()
}).

-export_records([online_userjson]).

-endif.
