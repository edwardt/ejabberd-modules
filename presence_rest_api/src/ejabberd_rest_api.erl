%% Feel free to use, reuse and abuse the code in this file.

-module(ejabberd_rest_api).

%% API.
-export([start/0,
		 stop/0
]).

%% API.

start() ->
    Apps = [
    		crypto,
    		ranch, 
    		cowboy, 
    		ejabberd_rest_api
    	 ],
    app_util:start_apps(Apps).
    
    
stop()->
    Apps = [
    		ejabberd_rest_api,
    		cowboy, 
    		ranch, 
    		crypto
    	 ],
    app_util:stop_apps(Apps).
