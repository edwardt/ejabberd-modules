-module(ejabberd_test_client).
-behaviour(gen_server).

-export([start/0]).
-export([start_link/1]).

-export([sanity_test/0]).

-export([init/1,
		handle_call/3,
		handle_cast/2,
		handle_info/2,
		code_change/3,
		terminate/2]).
		
-define(SERVER, ?MODULE).
-define(TestAgainAfter, 1000).
-define(ConfPath,"priv").
-define(ConfFile, "ejabberd_auth_spark.config").

-include_lib("ejabberd_auth_spark.hrl").
-include("exmpp.hrl").
-include("exmpp_client.hrl").
-include("exmpp_jid.hrl").

-record(state, {
	test_after = ?TestAgainAfter,
	exmpp_client,
	jid,
	email,
	password,
	access_token
}).
-type state() :: #state{}.

start() -> start_link().

start_link() -> start_link([{?ConfPath, ?ConfFile}]).
start_link(Args)->
  R = gen_server:start_link({local, ?SERVER}, ?MODULE, Args ,[]),
  {ok, Interval} = app_config_util:config_val(test_again, 	
  					Args, ?TestAgainAfter),
  erlang:send_after(Interval, self(), {sanity_test}),
  R.		
  
init(Args)->
  error_logger:info_msg("Initiating user_presence_db ~p with config ~p", [?SERVER, Args]),
  Start = app_util:os_now(),
  {Path, File} = Args,
  error_logger:info_msg("Initiating db ~p with config ~p ~p", [?SERVER, Path, File]),
  {ok, [ConfList]} = app_config_util:load_config(Path,File),
  error_logger:info_msg("~p config values ~p", [?SERVER, ConfList]),
  ok = load_config_mnesia(node(), ConfList),
  
  Pid = exmpp:start(),
 
  {ok, #state{exmpp_client = Pid}};

init(_Args)->
  init([{?ConfPath, ?ConfFile}]).
  
load_config_mnesia(Node, [])-> {error, empty_config};
load_config_mnesia(Node, List) when is_list(List)->
   mnesia:create_table(ejabberd_auth_spark,
   					[{attributes, 
   						record_info(fields, ejabberd_auth_spark_config)},
   					 {disc_copies, Node},
   					 {type, set}	
   					]),
   write_to_mnesia(List).
  
write_to_mnesia(List)->
   Environment = app_helper:get_config_from_list(
  							environment, List, undefined),
   SparkApiEndpoint = app_helper:get_config_from_list(
  							spark_api_endpoint, List, undefined),
   SparkAppId = app_helper:get_config_from_list(
  							spark_app_id , List, undefined),   
   SparkClientSecret = app_helper:get_config_from_list(
  							spark_client_secret, List, undefined),
   SparkCreateOAuthToken_Url = app_helper:get_config_from_list(
  							spark_create_oauth_accesstoken, List, undefined),
   MiniProfile_Url = app_helper:get_config_from_list(
  							auth_profile_miniProfile, List, undefined),   
   MemberStatus_Url = app_helper:get_config_from_list(
  							profile_memberstatus, List, undefined),							
   ConversationToken_Url = app_helper:get_config_from_list(
  							validate_conversation_token, List, undefined),
  							   
   SendIMMessage_Url = app_helper:get_config_from_list(
  							send_im_mail_message, List, undefined),
   SparkCreateOAuthToken_Url1 = 
  	   app_helper:bitstring_concat(SparkApiEndpoint,
  	   				SparkCreateOAuthToken_Url),
   MiniProfile_Url1 = 
  		app_helper:bitstring_concat(SparkApiEndpoint, 
  					MiniProfile_Url),
   MemberStatus_Url1 = 
   		app_helper:bitstring_concat(SparkApiEndpoint, 
   					MemberStatus_Url),
   ConversationToken_Url1 =
    	app_helper:bitstring_concat(SparkApiEndpoint, 	
    				ConversationToken_Url),
   SendIMMessage_Url1 = 
        app_helper:bitstring_concat(SparkApiEndpoint, 
        			SendIMMessage_Url),
 														
   CommunityBrandIdMap = app_helper:get_config_from_list(
  							community2brandId, List, undefined),				
  
  Record = #ejabberd_auth_spark_config{
     		environment = Environment,
			spark_api_endpoint = SparkApiEndpoint,
			spark_app_id = SparkAppId,
			spark_client_secret = SparkClientSecret,
			spark_create_oauth_accesstoken = SparkCreateOAuthToken_Url1,
			auth_profile_miniProfile = MiniProfile_Url1,
			profile_memberstatus = MemberStatus_Url1,
			validate_conversation_token = ConversationToken_Url1,
			send_im_mail_message = SendIMMessage_Url1,
			community_brandId_dict = CommunityBrandIdMap 
  },
  
  F = fun(Record) ->
  		mnesia:write(Record)
  end,
  mnesia:activity(transaction, F).   

sanity_test()->
  gen_server:call(?SERVER, sanity_test).
  
  
handle_call(sanity_test, From, State) ->
  
  MySession = exmpp_session:start({1,0}),
  %MyJID = exmpp_jid:make("bosh", "localhost", random),
  MyJID = State#state.jid,
  Password = get_auth_cookie(MyJID, AppID),
  exmpp_session:auth_basic_digest(MySession, MyJID, Password),
  {ok, _StreamId, _Features} = 
  	exmpp_session:connect_BOSH(MySession, ChatUrl,
					 		Host, []),
  Reply = session(MySession, MyJID),
  
  {reply, Reply, State};

handle_call(Req, From, State) ->
  error_logger:error_msg("Unknown request: ~p~n", [Req]),
  {reply, {error, {unknown_request, Req}}, State}.
  
handle_cast(Info, State) ->
  erlang:display(Info),
  {noreply, State}.

-spec handle_info(tuple(), state()) -> {ok, state()}.
handle_info(_Info, State) ->
  {ok, State}.

-spec handle_info(tuple(), pid(), state()) -> {ok, state()}.
handle_info(stop, _From, State)->
  terminate(normal, State).

-spec terminate(atom(), state()) -> ok.
terminate(Reason, State) ->
  error_logger:info_msg("~p at ~p terminated",[?SERVER, node()]), 
  
  ok.

code_change(_OldVsn, State, _Extra)->
   {ok, State}.
   

session(MySession, MyJID) ->
    %% Login with defined JID / Authentication:
    try exmpp_session:login(MySession, "PLAIN")
    catch
		throw:{auth_error, 'not-authorized'} ->
  			{error, {auth_error, 'not-authorized'}}
    end.




