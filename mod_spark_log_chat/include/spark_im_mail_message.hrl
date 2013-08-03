-ifndef(SPARK_IM_MAIL_MESSAGE_HRL).
-define(SPARK_IM_MAIL_MESSAGE_HRL, true).
-record(spark_im_mail_message, {
		recipientMemberId ::bitstring(),
		subject ::bitstring(), 
		body ::bitstring(), 
		mailtype ::bitstring(),
		originalMessageRepliedtoId ::bitstring()}).


-export_records([spark_im_mail_message]).


-endif.
