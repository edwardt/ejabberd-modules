-module(spark_jid).
-include("ejabberd.hrl").
-include("jlib.hrl").

-export([split_Jid/1]).
-export([reconstruct_spark_jid/2]).
-export([get_usr/1]).
get_usr(#jid{user = User, server = Server,
		   resource = Resource} = Jid)->
    {User, Server, Resource}.

split_Jid(Jid) when is_binary(Jid)->
	Jid0 = binary_to_list(Jid),
	split_Jid(Jid0);
	
split_Jid(Jid) when is_list(Jid)->  
   case re:split(Jid, "#") of 
     [AAJid, RealJid, TokenComId] -> 
   	 	[Token, CommunityId] = re:split(TokenComId, "-"),
	    ?INFO_MSG("Found AAJid ~p MemberJid ~p Token ~p CommunityId ~p",
	    			[AAJid, RealJid,Token,CommunityId]),
	    [AAJid, RealJid,Token,CommunityId]; 
   
   
   	 [RealJid, TokenComId] -> 
   	 	[Token, CommunityId] = re:split(TokenComId, "-"),
	    ?INFO_MSG("Found MemberJid ~p Token ~p CommunityId ~p",
	    			[RealJid,Token,CommunityId]),
	    [RealJid,Token,CommunityId];
	    
	 OldJid-> 
	 	case re:split(OldJid, "-") of
	 		 [A,B] -> 
	 		 		?INFO_MSG("Found MemberJid ~p, CommunityId ~p", [A,B]),		  
	 		 		[A,B];
	 		 E->E
	    end;
	 _ -> 
	   Jid
   end;
   
split_Jid(Jid) -> {error, {Jid, wrong_type}}.

reconstruct_spark_jid(A,C) when is_binary(A) ; is_binary(C)->
  Ret = <<A/binary,<<"-">>/binary,C/binary>>,
  erlang:binary_to_list(Ret);
reconstruct_spark_jid(A,C) when is_list(A) ; is_list(C)->
  lists:concat([A,"-",C]).
