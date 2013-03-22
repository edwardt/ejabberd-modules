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


%%-record(profile, {identity, server, lang, jid}).

%%-define(MYDEBUG(Format,Args),io:format("D(~p:~p:~p) : "++Format++"~n",
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

%% @spec (User::string(), Server::string(), Password::string()) ->
%%       ok | {error, ErrorType}
%% where ErrorType = empty_password | not_allowed | invalid_jid
set_password(_User, _Server, _Password) ->
    %% TODO security issue to log this, doit another way but also enough info for debugging
    ?DEBUG("~p with user ~p server ~p password ~p~n", [?CURRENT_FUNCTION_NAME(),_User, _Server, _Password]),
    RETVAL = {error, not_allowed},
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Check if the user and password can login in server.
%% @spec (User::string(), Server::string(), Password::string(),
%%        Digest::string(), DigestGen::function()) ->
%%     true | false
check_password(User, Server, Password, _Digest, _DigestGen) ->
    ?DEBUG("~p with user ~p server ~p password ~p digest ~p digestgen ~p~n", 
	   [?CURRENT_FUNCTION_NAME(), User, Server, Password, _Digest, _DigestGen]),
    RETVAL = check_password(User, Server, Password),
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Check if the user and password can login in server.
%% @spec (User::string(), Server::string(), Password::string()) ->
%%     true | false
check_password(User, Host, Password) ->
    ?DEBUG("~p with user ~p host ~p password ~p~n", [?CURRENT_FUNCTION_NAME(), User, Host, Password]),
    
    RETVAL = {error, not_implemented},
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @spec (User, Server, Password) -> {atomic, ok} | {atomic, exists} | {error, not_allowed}
try_register(_User, _Server, _Password) ->
    ?DEBUG("~p with user ~p server ~p password ~p~n", [?CURRENT_FUNCTION_NAME(), _User, _Server, _Password]),
    RETVAL = {error, not_allowed},
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Registered users list do not include anonymous users logged
dirty_get_registered_users() ->
    ?DEBUG("~p~n", [?CURRENT_FUNCTION_NAME()]),
    RETVAL = [],
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Registered users list do not include anonymous users logged
get_vh_registered_users(_Host) ->
    ?DEBUG("~p with host ~p~n", [?CURRENT_FUNCTION_NAME(), _Host]),
    RETVAL = [],
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Get the password of the user.
%% @spec (User::string(), Server::string()) -> Password::string()
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

%% @spec (User, Server) -> ok
%% @doc Remove user.

remove_user(_User, _Server) ->
    {error, not_allowed}.

%% @spec (User, Server, Password) -> ok | not_exists | not_allowed | bad_request | error
%% @doc Try to remove user if the provided password is correct.
%% The removal is attempted in each auth method provided:
%% when one returns 'ok' the loop stops;
%% if no method returns 'ok' then it returns the error message indicated by the last method attempted.
remove_user(_User, _Server, _Password) ->
    not_allowed.

%% @doc This is only executed by ejabberd_c2s for non-SASL auth client
plain_password_required() ->
    
    true.

%% @doc Flag to indicate if using external storage to cache credentials
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

