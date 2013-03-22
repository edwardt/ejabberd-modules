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
%%				       [calendar:local_time(),?MODULE,?LINE]++Args)).
-define(CURRENT_FUNCTION_NAME(), element(2, element(2, process_info(self(), current_function)))).


%%====================================================================
%% API
%%====================================================================
-spec start(Host::string()) -> ok | {error, not_started}.
%% @doc Perform any initialization needed for the module to run
start(Host) ->
    ?DEBUG("~p with host: ~p~n", [?CURRENT_FUNCTION_NAME(), Host]),
    
    RETVAL = {error, not_started}, 
    ?DEBUG("Spark authentication with status: ~p~n", [RETVAL]),    
    RETVAL.

%% @spec (User::string(), Server::string(), Password::string()) ->
%%       ok | {error, ErrorType}
%% where ErrorType = empty_password | not_allowed | invalid_jid
-spec set_password(User::string(), Server::string(), Password::string()) -> ok | {error, empty_password} | {error, not_allowed} | {error, invalid_jid}.
set_password(User, Server, Password) ->
    %% TODO security issue to log this, doit another way but also enough info for debugging
    ?DEBUG("~p with user ~p server ~p password ~p~n", [?CURRENT_FUNCTION_NAME(),User, Server, Password]),
    RETVAL = {error, not_allowed},
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Check if the user and password can login in server.
%% @spec (User::string(), Server::string(), Password::string(),
%%        Digest::string(), DigestGen::function()) ->
%%     true | false
-spec check_password(User::string(), Server::string(), Password::string(),Digest::string(), DigestGen::function()) ->
      true | false.
check_password(User, Server, Password, _Digest, _DigestGen) ->
    ?DEBUG("~p with user ~p server ~p password ~p digest ~p digestgen ~p~n", 
	   [?CURRENT_FUNCTION_NAME(), User, Server, Password, _Digest, _DigestGen]),
    RETVAL = check_password(User, Server, Password),
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Check if the user and password can login in server.
-spec check_password(User::string(), Host::string(), Password::string()) -> true | false | {error, not_implemented} | {error, term()}.
check_password(User, Host, Password) ->
    ?DEBUG("~p with user ~p host ~p password ~p~n", [?CURRENT_FUNCTION_NAME(), User, Host, Password]),
    
    RETVAL = {error, not_implemented},
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Try register new user. This is not needed as this will go through website/mobile site
-spec try_register(_User::string(), _Server::string(), _Password::string()) -> {atomic, ok} | {atomic, exists} | {error, not_allowed}.
try_register(_User, _Server, _Password) ->
    ?DEBUG("~p with user ~p server ~p password ~p~n", [?CURRENT_FUNCTION_NAME(), _User, _Server, _Password]),
    RETVAL = {error, not_allowed},
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Registered users list do not include anonymous users logged
-spec dirty_get_registered_users() -> [].
dirty_get_registered_users() ->
    ?DEBUG("~p~n", [?CURRENT_FUNCTION_NAME()]),
    RETVAL = [],
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Registered users list do not include anonymous users logged
-spec get_vh_registered_users(_Host::string())->[] | [string()].
get_vh_registered_users(_Host) ->
    ?DEBUG("~p with host ~p~n", [?CURRENT_FUNCTION_NAME(), _Host]),
    RETVAL = [],
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Get the password of the user.
-spec get_password(_User::string(), _Server::string()) -> false | string().
get_password(_User, _Server) ->
    ?DEBUG("~p with user ~p server ~p password ~p~n", [?CURRENT_FUNCTION_NAME(), _User, _Server]),
    RETVAL = false,
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

-spec get_password_s(_User::string(), _Server::string()) -> string(). 
get_password_s(_User, _Server) ->
    ?DEBUG("~p with user ~p server ~p~n", [?CURRENT_FUNCTION_NAME(), _User, _Server]),
    RETVAL = "",
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.
   
%% @doc check if user exists 
-spec is_user_exists(_User::string(), _Host::string()) ->true | false | {error, term()}. 
is_user_exists(_User, _Host) ->
    ?DEBUG("~p with user ~p host ~p~~n", [?CURRENT_FUNCTION_NAME(), _User, _Host]),
    RETVAL = {error, not_implemented},
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.     

%% @doc Remove user.This function is not allowed, this case taken by mainsite.
-spec remove_user(_User::string(), _Server::string())-> {error, not_allowed}.
remove_user(_User, _Server) ->
    ?DEBUG("~p with user ~p server ~p~n", [?CURRENT_FUNCTION_NAME(), _User, _Server]),
    RETVAL = {error, not_allowed},
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Try to remove user if the provided password is correct. This function is not allowed.
%% @doc User removal be taken care by main site. 
-spec remove_user(_User::string(), _Server::string(), _Password::string()) -> not_allowed.
remove_user(_User, _Server, _Password) ->
    ?DEBUG("~p with user ~p server password ~p~n", [?CURRENT_FUNCTION_NAME(), _User, _Server, _Password]),
    RETVAL = not_allowed,
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc This is only executed by ejabberd_c2s for non-SASL auth client
-spec plain_password_required()-> true.
plain_password_required() ->
    ?DEBUG("~p~n", [?CURRENT_FUNCTION_NAME()]),
    RETVAL = true,
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.   
   
%% @doc Flag to indicate if using external storage to cache credentials
-spec store_type()-> external.
store_type() ->
    ?DEBUG("~p~n", [?CURRENT_FUNCTION_NAME()]),
    RETVAL = external,
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.  

%%====================================================================
%% Internal functions
%%====================================================================
%% @private

%% @private

%%%%%% EUNIT %%%%%%%%%%%%%%%%%%
-ifdef(TEST).






-endif.

