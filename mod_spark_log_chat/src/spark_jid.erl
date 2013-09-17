-module(spark_jid).
-include("ejabberd.hrl").

-export([split_Jid/1]).
-export([reconstruct_spark_jid/2]).


split_Jid(Jid) ->  
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
   end.


reconstruct_spark_jid(A,C) when is_binary(A) ; is_binary(C)->
  Ret = <<A/binary,<<"-">>/binary,C/binary>>,
  erlang:binary_to_list(Ret);
reconstruct_spark_jid(A,C) when is_list(A) ; is_list(C)->
  lists:concat([A,"-",C]).
