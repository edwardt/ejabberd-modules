-module(mod_presence_srv).
-behaviour(gen_server).


-export([list_online/1,
		list_online/2,
		list_all_online/1,
		list_all_online/2]).

-export([start/0, stop/0]).
-export([start_link/1]).
-export([
		 handle_call/3,
		 handle_cast/2,
		 handle_info/2, 
		 terminate/2, 
		 code_change/3]).