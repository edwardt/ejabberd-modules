-ifndef(USER_WEBPRESENCE_HRL).
-define(USER_WEBPRESENCE_HRL, true).

-record(user_webpresence, {
	memberid :: bitstring(),
	brandid :: bitstring(),
	presence :: bitstring(),
	token :: pos_integer()
}).


-endif.
