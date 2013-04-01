
%%%----------------------------------------------------------------------
%%%
%%% @author : Edward Tsang <etsang@spark.net>
%%% @doc Retrieve configurtion for spark authentication
%%% Created : 20 Mar 2013
%%%---------------------------------------------------------------------
%%%
%%% Copyright (c)
%%%
%%%----------------------------------------------------------------------
%%% @end

%% @doc Retrieve configurtion for spark authentication
%%      
%% @end
-module(ejabberd_auth_spark_config).
-author('etsang@spark.net').

%% External exports

-export([
	get_spark_authservice_endpoint/1,
        get_spark_client_secrete/1,
        get_spark_application_id/1, 
	get_rest_client_timeout_in_sec/1, 
	get_rest_call_retry_attempt/1,
	get_spark_communityId_brandId_mapping/1
  %%      url_token_replace/3
	]).
%TODO change it to true at end of cycle
-define(TEST, true).


-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").

-endif.

-include("ejabberd.hrl").
-include("ejabberd_config.hrl").


%% @doc get the rest api authentication endpoint from config file 
%% @end
-spec get_spark_authservice_endpoint(Host::string()) -> string() | {error, endpoint_notfound}.
get_spark_authservice_endpoint(Host) ->
    get_spark_auth_service_config(Host, spark_auth_endpoint). 

%% @doc get the rest applicationId from config file
-spec get_spark_application_id(Host::string()) -> string() | {error, not_found}.
get_spark_application_id(Host) ->
    get_spark_auth_service_config(Host, spark_application_id). 
   
%% @doc get the rest client secrete from config file 
%% @end
-spec get_spark_client_secrete(Host::string()) -> integer() | {error, not_found}.
get_spark_client_secrete(Host) ->
    case get_spark_auth_service_config(Host,spark_client_secrete) of
       {error, REASON} -> {error, REASON}; 	
       HasValue -> string_to_integer(HasValue)
    end. 

%% @doc get the rest client time out value in seconds from config file 
%% @end
-spec get_rest_client_timeout_in_sec(Host::string()) -> integer() | {error, not_found}.
get_rest_client_timeout_in_sec(Host) ->
    Val = case get_spark_auth_service_config(Host,rest_client_timeout_in_sec) of
       {error, REASON} -> {error, REASON}; 
        HasValue -> HasValue
    end,
    case Val of 
       {error, _} -> 15;
       Else -> Else
    end.

%% @doc get the rest client call retry attempt from config file
%% @end
-spec get_rest_call_retry_attempt(Host::string()) -> integer() | {error, not_found}.
get_rest_call_retry_attempt(Host) ->
    Val = case get_spark_auth_service_config(Host,rest_call_retry_attempt) of
        {error, REASON} -> {error, REASON}; 
    	HasValue -> HasValue
    end,
    
    case Val of 
        {error, _Reason} -> 0;
        Else -> Else
    end
    .

%% @doc Get the CommunityId to BrandId maping from config
%% @end
-spec get_spark_communityId_brandId_mapping(Host::string()) -> {tuple()} | {error, not_found}.
get_spark_communityId_brandId_mapping(Host) ->
    case get_spark_auth_service_config(Host,community2brandId) of
       {error, REASON} -> {error, REASON}; 	
       HasValue -> HasValue
    end. 



%% @doc get the authentication endpoint rest client to talk to
%% @end
get_spark_auth_service_config(Host, TokenName) ->
    io:fwrite("going to call get_local_option"),
    case ejabberd_config:get_local_option({TokenName, Host}) of
	undefined -> {error, undefined};
        undef -> {error, undefined};
	Val   -> Val
    end.

%% @doc get the mini profile endpoint rest client to talk to
%% @end
get_miniProfile_service_endpoint(Host)->
    get_spark_auth_service_config(Host, auth_profile_miniProfile).

%% @doc get the isUserExists endpoint rest client to talk to
%% @end
get_isUserExists_service_endpoint(Host)->
    get_spark_auth_service_config(Host, auth_profile_miniProfile).


%% @doc get the Url token replace
%% @end
%%-spec url_token_replace(Url::string(), TokenList::[string()], ReplaceBy::[string()]) -> {error, atom()} | string().
%%url_toke
%%url_token_replace(Url, TokenList, ReplaceBy) when is_list(TokenList) andalso when is_list(ReplaceBy) ->
    


%% @private
%% @doc convert string to integer
%% @end
-spec string_to_integer(StringValue::string()) -> integer() | {error, atom()}.
string_to_integer("") -> 
	{error, cannot_convert};
string_to_integer(StringValue) when is_list(StringValue)->
    case string:to_integer(StringValue) of
    	{Int, _} -> Int;
        _ -> {error, cannot_convert}
    end;
string_to_integer(_) ->        
	{error, cannot_convert}.
	
%%%%%% EUNIT %%%%%%%%%%%%%%%%%%
-ifdef(TEST).
string_to_integer_emptystring_test() ->[?assertEqual({error, cannot_convert}, string_to_integer("")), 
				       ?assertEqual({error, cannot_convert}, string_to_integer(badtype))].
string_to_integer_test()-> [?assertEqual(1, string_to_integer("1"))].

get_spark_communityId_brandId_mapping_test()-> [?assertEqual([{spark, 1, 1001},{jdate, 3, 1003},{cupid, 10, 1015},{bbw, 23, 90410},{blacksingle, 24, 90510}], get_spark_communityId_brandId_mapping("developer01"))].

get_spark_authservice_endpoint_test()-> [?assertEqual("http://api.dev.spark.net", get_spark_authservice_endpoint("developer01"))].

get_rest_client_timeout_in_sec_test()-> [?assertEqual("15", get_rest_client_timeout_in_sec("developer01"))].

get_spark_client_secrete_test()-> [?assertEqual("nZGVVfj8dfaBPKsx_dmcRXQml8o5N-iivf5lBkrAmLQ1", get_spark_client_secrete("developer01"))].

get_rest_call_retry_attempt_test()->[?assertEqual("0", get_rest_call_retry_attempt("developer01"))].

get_spark_application_id_test()-> [?assertEqual("1054", get_spark_application_id("developer01"))].

get_spark_auth_service_config_test()-> [?assertEqual("spark", get_spark_auth_service_config("developer01", auth_method)), 
					?assertEqual({error, undefined}, get_spark_auth_service_config("developer01", willnotfind))].

-endif.
