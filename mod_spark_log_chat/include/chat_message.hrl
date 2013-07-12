-record(chat_message, {
		from ::bitstring(),
		from_brandId  ::bitstring(),
		to  ::bitstring(),
		to_brandId ::bitstring(),
		type ::bitstring(), 
		format ::bitstring(),
		subject ::bitstring(), 
		body ::bitstring(), 
		thread ::bitstring(),
		time_stamp ::bitstring()}).


-export_records([chat_message]).


