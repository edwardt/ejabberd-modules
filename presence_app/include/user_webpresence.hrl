-ifndef(USER_WEBPRESENCE_HRL).
-define(USER_WEBPRESENCE_HRLL, true).

-record(user_webpresence, {
	memberid :: bitstring(),
	brandid :: bitstring(),
	presence :: bitstring(),
	token :: pos_integer()
}).

-export_records([user_webpresence]).
-endif.