%%%----------------------------------------------------------------------
%%%
%%% @author : Edward Tsang <etsang@spark.net>
%%% @doc Authentication client against spark authentication server
%%% Created : 20 Mar 2013
%%%---------------------------------------------------------------------
%%%
%%% Copyright (c)
%%%
%%%----------------------------------------------------------------------

%% @doc ejabberd_auth_spark exposes the public api to hook up wih ejabberd
%% @doc internally it is using a rest client to authentication
-module(ejabberd_auth_spark).
-author('etsang@spark.net').

%% External exports

-export([start/1,
	 set_password/3,
	 check_password/3,
	 check_password/5,
	 try_register/3,
	 dirty_get_registered_users/0,
	 get_vh_registered_users/1,
	 get_password/2,
	 get_password_s/2,
	 is_user_exists/2,
	 remove_user/2,
	 remove_user/3,
	 store_type/0,
	 plain_password_required/0
	]).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").
-endif.

-include("ejabberd.hrl").
-include("jlib.hrl").
-include("web/ejabberd_http.hrl").
-include("web/ejabberd_web_admin.hrl").

-record(profile, {identity, server, lang, jid}).

-define(MYDEBUG(Format,Args),io:format("D(~p:~p:~p) : "++Format++"~n",
				       [calendar:local_time(),?MODULE,?LINE]++Args)).
-define(CURRENT_FUNCTION_NAME(), element(2, element(2, process_info(self(), current_function)))).


%%====================================================================
%% API
%%====================================================================
start(_Host) ->
    ?DEBUG("~p with host: ~p~n", [?CURRENT_FUNCTION_NAME(), _Host]),
    
    RETVAL = {error, not_started}, 
    ?DEBUG("Spark authentication with status: ~p~n", [RETVAL]),    
    RETVAL.

set_password(_User, _Server, _Password) ->
    %% TODO security issue to log this, doit another way but also enough info for debugging
    ?DEBUG("~p with user ~p server ~p password ~p~n", [?CURRENT_FUNCTION_NAME(),_User, _Server, _Password]),
    RETVAL = {error, not_allowed},
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

check_password(User, Server, Password, _Digest, _DigestGen) ->
    ?DEBUG("~p with user ~p server ~p password ~p digest ~p digestgen ~p~n", 
	   [?CURRENT_FUNCTION_NAME(), User, Server, Password, _Digest, _DigestGen]),
    RETVAL = check_password(User, Server, Password),
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

check_password(User, Host, Password) ->
    ?DEBUG("~p with user ~p host ~p password ~p~n", [?CURRENT_FUNCTION_NAME(), User, Host, Password]),
    
    RETVAL = {error, not_implemented},
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

try_register(_User, _Server, _Password) ->
    ?DEBUG("~p with user ~p server ~p password ~p~n", [?CURRENT_FUNCTION_NAME(), _User, _Server, _Password]),
    RETVAL = {error, not_allowed},
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

dirty_get_registered_users() ->
    ?DEBUG("~p~n", [?CURRENT_FUNCTION_NAME]),
    RETVAL = [],
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

get_vh_registered_users(_Host) ->
    ?DEBUG("~p with host ~p~n", [?CURRENT_FUNCTION_NAME(), _Host]),
    RETVAL = [],
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

get_password(_User, _Server) ->
    ?DEBUG("~p with user ~p server ~p password ~p~n", [?CURRENT_FUNCTION_NAME(), _User, _Server]),
    RETVAL = false,
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

get_password_s(_User, _Server) ->
    ?DEBUG("~p with user ~p server ~p~n", [?CURRENT_FUNCTION_NAME(), _User, _Server]),
    RETVAL = "",
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.
   
%% @spec (User, Server) -> true | false | {error, REASON}
%% 
is_user_exists(User, Host) ->
    {error, not_implemented}.

remove_user(_User, _Server) ->
    {error, not_allowed}.

remove_user(_User, _Server, _Password) ->
    not_allowed.

plain_password_required() ->
    
    true.

store_type() ->
    external.

%%====================================================================
%% Internal functions
%%====================================================================
%% @private

%% @private

%%%%%% EUNIT %%%%%%%%%%%%%%%%%%
-ifdef(TEST).


-endif.

