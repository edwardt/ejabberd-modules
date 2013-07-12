-record(chat_message, {
		from = "" ::string(),
		from_brandId = "" ::string(),
		to = "" ::string(),
		to_brandId = "" ::string(),
		type = "chat" ::string(), 
		format = "text" ::string(),
		subject = "" ::string(), 
		body = "" ::string(), 
		thread = "" ::string(),
		time_stamp = "" ::string()}).


-export_records([chat_message]).


