-ifndef(WEB_PRES_HRL).
-define(WEB_PRES_HRL, true).

-record(web_pres, {
	count :: bitstring(),
	token :: pos_integer()
}).

%-export_records([web_pres]).
-endif.
