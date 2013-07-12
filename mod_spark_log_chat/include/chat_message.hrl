-record(chat_message, {
		from ::string(),
		from_brandId  ::string(),
		to  ::string(),
		to_brandId ::string(),
		type ::string(), 
		format ::string(),
		subject ::string(), 
		body ::string(), 
		thread ::string(),
		time_stamp ::string()}).


-export_records([chat_message]).


