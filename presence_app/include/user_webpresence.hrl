-ifndef(USER_WEBPRESENCE_HRL).
-define(USER_WEBPRESENCE_HRLL, true).

-include("ejabberd.hrl").
-include("jlib.hrl").

-type jid() :: #jid{}.

-record(user_webpresence, {
	jid :: jid(),
	presence :: string(),
	since :: integer()
}).

-export_records([user_webpresence]).
-endif.