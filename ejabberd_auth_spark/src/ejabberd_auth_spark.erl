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
%%% @end

%% @doc ejabberd_auth_spark exposes the public api to hook up wih ejabberd
%%       internally it is using a rest client to authentication
%% @end
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
%TODO change it to true at end of cycle
-define(TEST, true).


-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").
-endif.

-include("ejabberd.hrl").
-include("jlib.hrl").
-include("web/ejabberd_http.hrl").
-include("web/ejabberd_web_admin.hrl").


%%-record(profile, {identity, server, lang, jid}).
%%TODO the following is janky becasue we are not finding ejabbberd_logger_h.beam just do this before fixing the build script
-define(MYDEBUG(Format,Args),io:format("D(~p:~p:~p) : "++Format++"~n",
				       [calendar:local_time(),?MODULE,?LINE]++Args)).

%%TODO READ THIS FROM config

-define(SPARKAUTH_URI, "http://api....").
-define(CURRENT_FUNCTION_NAME(), element(2, element(2, process_info(self(), current_function)))).
-define(AUTHENTICATED, 200).
-define(DefaultType, json).


%%====================================================================
%% API
%%====================================================================
-spec start(Host::string()) -> ok | {error, not_started}.
%% @doc Perform any initialization needed for the module to run
%% @end
start(Host) ->
    ?DEBUG("~p with host: ~p~n", [?CURRENT_FUNCTION_NAME(), Host]),
    RETVAL = ok,
    ?DEBUG("Spark authentication with status: ~p~n", [RETVAL]),    
    RETVAL.

%% @doc Set user and password onto server. This is not needed; will be done on mainsite
%% @end
-spec set_password(User::string(), Server::string(), Password::string()) -> {error, not_allowed}.
set_password(User, Server, Password) ->
    
    ?ERROR_MSG("~p with user ~p server ~p password ~p~n", [?CURRENT_FUNCTION_NAME(),User, Server, get_password_string(Password)]),
    RETVAL = {error, not_allowed},
    ?ERROR_MSG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Check if the user and password can login in server.
%% @end
-spec check_password(User::string(), Server::string(), Password::string(),Digest::string(), DigestGen::function()) ->
     false.
check_password(User, Server, Password, _Digest, _DigestGen) ->
    ?INFO_MSG("~p with user ~p server ~p password ~p digest ~p digestgen ~p~n", 
	   [?CURRENT_FUNCTION_NAME(), User, Server, get_password_string(Password), _Digest, _DigestGen]),
    RETVAL = check_password(User, Server, Password),
    ?INFO_MSG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Check if the user and password can login in server.
%% @end
-spec check_password(User::string(), Host::string(), Password::string()) -> false .
check_password(User, Host, "") ->
    ?ERROR_MSG("Password is missing ~p with user ~p host ~p password ~p~n", 
	    [?CURRENT_FUNCTION_NAME(), User, Host, ""]),
    false;
check_password(User, Host, Password) when is_list(Password) ->
    ?DEBUG("~p with user ~p host ~p password ~p~n", [?CURRENT_FUNCTION_NAME(), User, Host, get_password_string(Password)]),
    LUser = jlib:nodeprep(User),
    LHost = jlib:nameprep(Host),
    %UserHost = {LUser, LHost},  
    RETVAL =  case authenticate_request(LHost, LUser, Password) of
                   {ok, authenticated} -> true;
                   {error, REASON} -> 
                                    ?INFO_MSG("Authenication failed ~p ~p~n",[?CURRENT_FUNCTION_NAME(), {error, REASON}]),
                                    false;
                   Error -> 
    			            ?ERROR_MSG("Authenication failed ~p ~p~n",[?CURRENT_FUNCTION_NAME(), {error, Error}]),
                                    false 
              end,
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL;
check_password(User, Host, Password) ->
    ?ERROR_MSG("Parameters missing ~p with user ~p host ~p password ~p~n", 
	    [?CURRENT_FUNCTION_NAME(), User, Host, get_password_string(Password)]),
    false.

%% @doc Try register new user. This is not needed as this will go through website/mobile site
%% @end
-spec try_register(_User::string(), _Server::string(), _Password::string()) -> {error, not_allowed}.
try_register(_User, _Server, _Password) ->
    ?DEBUG("~p with user ~p server ~p password ~p~n", [?CURRENT_FUNCTION_NAME(), _User, _Server, get_password_string(_Password)]),
    RETVAL = {error, not_allowed},
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Registered users list do not include anonymous users logged. This functionality we don't care.
%% @end
-spec dirty_get_registered_users() -> [].
dirty_get_registered_users() ->
    ?DEBUG("~p~n", [?CURRENT_FUNCTION_NAME()]),
    RETVAL = [],
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Registered users list do not include anonymous users logged. This function is not allowed, we just don't care.
%% @end
-spec get_vh_registered_users(_Host::string())-> false.
get_vh_registered_users(_Host) ->
    ?DEBUG("~p with host ~p~n", [?CURRENT_FUNCTION_NAME(), _Host]),
    RETVAL = false,
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Get the password of the user. This function is not allowed, this case taken by mainsite.
%% @end
-spec get_password(_User::string(), _Server::string()) -> false | string().
get_password(_User, _Server) ->
    ?DEBUG("~p with user ~p server ~p~n", [?CURRENT_FUNCTION_NAME(), _User, _Server]),
    RETVAL = false,
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Get the password of the user. This function is not allowed, this case taken by mainsite.
%% @end
-spec get_password_s(_User::string(), _Server::string()) -> {error, not_allowed}. 
get_password_s(_User, _Server) ->
    ?DEBUG("~p with user ~p server ~p~n", [?CURRENT_FUNCTION_NAME(), _User, _Server]),
    RETVAL = {error, not_allowed},
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.
   
%% @doc check if user exists 
%% This function checks user existence on database or on other authentication module.
%% We hit our authentication api to check for user existence
%% @end
-spec is_user_exists(_User::string(), _Host::string()) ->true | false | {error, atom()}.
is_user_exists(User, Host) ->
    ?DEBUG("~p with user ~p host ~p~~n", [?CURRENT_FUNCTION_NAME(), User, Host]),
    LUser = jlib:nodeprep(User),
    LHost = jlib:nameprep(Host),
    %UserHost = {LUser, LHost},
    {{serviceEndpoint, BaseServiceEndpoint}, {appId, AppId}, {client_secret, ClientSecret}} = get_global_call_parameters(LHost),
    ResourceEndpoint = ejabberd_auth_spark_config:get_isUserExists_service_endpoint(LHost),

    Val = case spark_parse_loginData:get_loginData(LUser, LHost) of
         {ok, {brandid, BrandId}, {memberid, MemberId}} -> {ok, {brandid, BrandId}, {memberid, MemberId}};  
         {error, _, _, Reason} -> {error, Reason};
         {error, Reason1} -> {error, Reason1};
         _ ->   {error, not_found}                         
    end,
    {Url, Verb1} = case  ResourceEndpoint of 
         {error, _Reason} -> ?ERROR_MSG("Error in calling is user exists Error ~p~n", [?CURRENT_FUNCTION_NAME(), _Reason]), 
			    {error, _Reason};   
         {EndPoint, Verb} -> {EndPoint, Verb};        
	 _ -> {error, not_found}
    end,
   
    Response =  
    case Val of
      {ok, {brandid, BrandId1}, {memberid, MemberId1}} ->
                                 ResourceEndpoint1 = re:replace(Url, "{brandId}", BrandId1, [global, {return, list}]),
   				 ResourceEndpoint2 = re:replace(ResourceEndpoint1, "{applictionId}", AppId, [global, {return, list}]),
    				 ResourceEndpoint3 = re:replace(ResourceEndpoint2, "{memberId}", MemberId1, [global, {return, list}]),
    				_Url = restc:construct_url(BaseServiceEndpoint, ResourceEndpoint3,["client_secret", ClientSecret]),
    				case {Url, Verb1} of
         		             {error, _Reason1} -> {error, _Reason1};
                                     {Url, Verb2} ->  post_isUserExists_request(Verb2, json, _Url, [200], []);
         		             _ -> {error, not_found}
    				end;
      {error, _Reason1}  -> {error, _Reason1};
      Else -> {error, Else}
    end,

    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), Response]),
    Response.     

%% @doc Remove user.This function is not allowed, this case taken by mainsite.
%% @end
-spec remove_user(_User::string(), _Server::string())-> {error, not_allowed}.
remove_user(_User, _Server) ->
    ?DEBUG("~p with user ~p server ~p~n", [?CURRENT_FUNCTION_NAME(), _User, _Server]),
    RETVAL = {error, not_allowed},
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc Try to remove user if the provided password is correct. This function is not allowed.
%% User removal be taken care by main site. 
%% @end
-spec remove_user(_User::string(), _Server::string(), _Password::string()) -> not_allowed.
remove_user(_User, _Server, _Password) ->
    ?DEBUG("~p with user ~p server ~p password ~p~n", [?CURRENT_FUNCTION_NAME(), _User, _Server, _Password]),
    RETVAL = not_allowed,
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.

%% @doc This is only executed by ejabberd_c2s for non-SASL auth client
%% @end
-spec plain_password_required()-> true.
plain_password_required() ->
    ?DEBUG("~p~n", [?CURRENT_FUNCTION_NAME()]),
    RETVAL = false,
    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.   
   
%% @doc Flag to indicate if using external storage to cache credentials
%% TODO: I do not think we store any password right in external storage? 
%% @end
-spec store_type()-> scram.
store_type() ->
    ?DEBUG(" store type ~p~n", [stored_type]),
    RETVAL = scram,
    ?DEBUG("~p with status ~p", [?CURRENT_FUNCTION_NAME(), RETVAL]),
    RETVAL.  

%%====================================================================
%% Internal functions
%%====================================================================
%% @private
%% @doc check for the authentication http post response for Success is true and error term is null
%%      anything else is error and considered authentication error and failed.
%% @end
-spec check_auth_response(AuthStatus::[tuple()]) -> {ok, authenticated} | {error, term()} | term().
check_auth_response(AuthStatus) ->
       case AuthStatus of
    		[_, _, _, _, _, _, _,
          	  _, _, _, _, _, _, _, _,
          	 {<<"subscriptionStatus">>,<<"Member">>},
          	 _, _, _] -> {ok, authenticated};
    		[_, _, _, _, _, _, _,
          	  _, _, _, _, _, _, _, _,
          	 {<<"subscriptionStatus">>,_},
          	 _, _, _] -> {ok, non_subscriber};
		{error, Reason} -> {error, Reason};
 		Error -> {error, Error}
       end.

check_isUser_response(IsUserStatus)->
    case IsUserStatus of
         [{<<"subscriptionStatus">>, "Member"}] -> {ok, subscriber};
         [{<<"subscriptionStatus">>, _ }] -> {ok, non_subscriber};
         {error, Reason} -> {error, Reason};
         Error -> {error, Error}
    end.


%% @private
%% @doc Get Parameters to make restful call
%% @end
get_global_call_parameters(Host)->
    BaseServiceEndpoint = ejabberd_auth_spark_config:get_spark_authservice_endpoint(Host),
    AppId = ejabberd_auth_spark_config:get_spark_application_id(Host),
    ClientSecret = ejabberd_auth_spark_config:get_spark_client_secrete(Host),
    {{serviceEndpoint, BaseServiceEndpoint}, {appId, AppId}, {client_secret, ClientSecret}}.

%% @private
%% @doc authenticate against api server from ejabberd Jid
%% @end
-spec authenticate_request(Host::string(), Email::string(), Password::string()) -> {ok, authenticated} | {error, term()} | term().
authenticate_request(Host, User, Password) ->    
    {{serviceEndpoint, BaseServiceEndpoint}, {appId, _AppId}, {client_secret, _ClientSecret}} = get_global_call_parameters(Host),
    ResourceEndpoint = ejabberd_auth_spark_config:get_authentication_service_endpoint(Host),
    Val = case spark_parse_loginData:get_loginData(User, Host) of
	 {ok, {brandid, BrandId}, {memberid, MemberId}} -> {ok, {brandid, BrandId}, {memberid, MemberId}};
         {error, {brandid, _}, {memberid, _}, Reason} -> {error, Reason};
         {error, _, _, Reason1} -> {error, Reason1};
         {error, Reason2} -> {error, Reason2};
         _ -> {error, not_found}                           
    end,
    {Url, Verb1}  = case  ResourceEndpoint of 
         {error, _Reason} -> ?ERROR_MSG("Error in calling is user exists Error ~p~n", [?CURRENT_FUNCTION_NAME(), _Reason]), 
			    {error, _Reason}; 	 
	 {EndPoint, Verb} -> {EndPoint, Verb};          
	 _ -> {error, not_found}
    end,
    
    Response =  
    case Val of
      {ok, {brandid, BrandId1}, {memberid, MemberId1}} ->
                                 ResourceEndpoint1 = re:replace(Url, "{brandId}", BrandId1, [global, {return, list}]),
   				 ResourceEndpoint2 = re:replace(ResourceEndpoint1, "{targetMemberId}", MemberId1, [global, {return, list}]),
    				 ResourceEndpoint3 = re:replace(ResourceEndpoint2, "{memberId}", MemberId1, [global, {return, list}]),
    				_Url = restc:construct_url(BaseServiceEndpoint, ResourceEndpoint3,["access_token", Password]),
    				case {Url, Verb1} of
         		             {error, _Reason1} -> {error, _Reason1};
                                     {Url, Verb2} ->  post_authenticate_request(Verb2, json, _Url, [200], [], [""]);
         		             _ ->  {error, not_found}
    				end;
      {error, _Reason1}  -> {error, _Reason1};
      Else -> {error, Else}
    end,

    ?DEBUG("~p with status ~p~n", [?CURRENT_FUNCTION_NAME(), Response]),
    Response.


%% @private
%% @doc post the Authentication Http Post request to the api server. Return {ok, authentication}
%% if the http code returns 200 and the Response body constains no error message and the Success Status is true 
%% @end
%% https://api.spark.net/brandId/1003/application/1000/member/133272351/status?client_secret=SXO0NoMjOqPDvPNGmEwZsHxnT5oyXTmYKpBXCx3SJTE1
-spec post_authenticate_request(Method::atom(), Type::atom(), Url::string(), Expect::[atom()], Headers::[term()], Body::[term()]) -> {ok, authenticated} | {error, term()} | term().
post_authenticate_request(Method, Type, Url, Expect, Headers, Body) ->
    
    RetValue = 
       case restc:request(Method, Type, Url, [Expect], Headers, Body) of
	    {ok, Status, H, B} -> {ok, Status, H, B};
            {error, Status, _H, _B} -> {error, Status, _H, _B}; 
            Status -> Status
       end,
    ?ERROR_MSG("RestCall failed with status ~p ~p~n", 
	    [?CURRENT_FUNCTION_NAME(), RetValue]),    
   
    Status1 = case RetValue of
	    {ok, ?AUTHENTICATED, _, ResponseBody} -> check_auth_response(ResponseBody);
            ResponseBody -> ?INFO_MSG("RestCall response malformed with status ~p ~p~n",
            [?CURRENT_FUNCTION_NAME(), ResponseBody]), 
		     {error, bad_responsebody}
    end,
    case Status1 of 
         {ok, ?AUTHENTICATED, _ServerInfo, ResponseBody1} -> check_auth_response(ResponseBody1);
         {error, Reason} -> {error, Reason};
         Else -> Else
    end.

post_isUserExists_request(Method, Type, Url, Expect, Headers) ->
    RetVal = 
       case restc:request(Method, Type, Url, Expect, Headers) of
	    {ok, Status, H, B} -> {ok, Status, H, B};
            {error, Status, _H, _B} ->     
                                  ?ERROR_MSG("RestCall failed with status ~p ~p~n", [?CURRENT_FUNCTION_NAME(), Status]), 
                                  {error, Status, _H, _B}; 
            Status -> Status
       end,
    case RetVal of
	{ok, ?AUTHENTICATED, _, ResponseBody} -> check_isUser_response(ResponseBody);
        ResponseBody -> ?INFO_MSG("RestCall response malformed with status ~p ~p~n",
                         [?CURRENT_FUNCTION_NAME(), ResponseBody]), 
		         {error, bad_responsebody}
    end.   

%% @private
%% @doc get access expiration time
%% @end
%%-spec get_access_expiration()->
   

%% @private
%% @doc get password to be printed to log as ******
%% @end
-spec get_password_string(_Password::string())-> string().
get_password_string("") -> 
    ""; 
get_password_string(_Password) when is_list(_Password)->
    "******".
string_to_integer(StringValue)->
    case string:to_integer(StringValue) of
    	{Int, _} -> Int;
        Else -> Else
    end.

%%%%%% EUNIT %%%%%%%%%%%%%%%%%%
-ifdef(TEST).

%%get_spark_authservice_endpoint_test()->[?assertEqual({error, endpoint_notfound}, get_spark_authservice_endpoint("BadHost")),
%%					?assertEqual("https://api.spark.test", get_spark_authservice_endpoint("GoodHost"))].

get_password_string_test()-> [?assertEqual("******", get_password_string("Password")),
		       ?assertEqual("******", get_password_string(anyValue))].

store_type_No_Password_Stored_test()-> ?assertEqual(scram, store_type()).

plain_password_always_required_test()-> ?assertEqual(false, plain_password_required()).

dirty_get_registered_users_return_emptylist_test()-> ?assertEqual([], dirty_get_registered_users()).
						     

get_vh_registered_users_return_false_test() -> ?assertEqual(false, get_vh_registered_users("SomeHost")).

remove_user_not_allowed_test()-> [?assertEqual(not_allowed,remove_user("SomeUser","SomeHost","SomePassword")),
				 ?assertEqual(not_allowed,remove_user(anyValue,anyValue,anyValue)),
				 ?assertEqual({error, not_allowed}, remove_user("SomeUser","SomeHost")),
				 ?assertEqual({error, not_allowed}, remove_user(anyValue,anyValue))].

try_register_not_allowed_test()->[?assertEqual({error, not_allowed}, try_register("SomeUser", "SomeServer", "SomePassword")),
			       ?assertEqual({error, not_allowed}, try_register(anyValue,anyValue,anyValue))]. 

set_password_not_allowed_test()->[?assertEqual({error, not_allowed}, set_password("SomeUser", "SomeServer", "SomePassword")),
			       ?assertEqual({error, not_allowed}, set_password(anyValue,anyValue,anyValue))]. 



check_password_return_false_test()->[?assertEqual(false,check_password("SomeUser", "SomeServer", "SomePassword","SomeDigest","DigestGen")),
				     ?assertEqual(false,check_password(anyValue, anyValue, anyValue, anyValue, anyValue))].

check_password_return_test()->[?assertEqual(true,check_password("SomeUser", "SomeHost", "SomePassword")),
			       ?assertEqual(true,check_password(anyValue, anyValue, anyValue))].


get_password_return_false_test() -> [?assertEqual(false, get_password("SomeUser", "SomeServer")),
				     ?assertEqual(false, get_password(anyValue, anyValue)),
				     ?assertEqual({error, not_allowed}, get_password_s("SomeUser", "SomeServer")),
				     ?assertEqual({error, not_allowed}, get_password_s(anyValue, anyValue))].

is_user_exists_test_return_true()-> [?assertEqual(true, is_user_exists("SomeUser", "SomeHost")),
				     ?assertEqual(true, is_user_exists(anyValue, anyValue))].

-endif.

