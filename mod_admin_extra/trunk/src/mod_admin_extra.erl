%%%-------------------------------------------------------------------
%%% File    : mod_admin_extra.erl
%%% Author  : Badlop <badlop@process-one.net>
%%% Purpose : Contributed administrative functions and commands
%%% Created : 10 Aug 2008 by Badlop <badlop@process-one.net>
%%%
%%%
%%% ejabberd, Copyright (C) 2002-2008   ProcessOne
%%%
%%% This program is free software; you can redistribute it and/or
%%% modify it under the terms of the GNU General Public License as
%%% published by the Free Software Foundation; either version 2 of the
%%% License, or (at your option) any later version.
%%%
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%%% General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License
%%% along with this program; if not, write to the Free Software
%%% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
%%% 02111-1307 USA
%%%
%%%-------------------------------------------------------------------

-module(mod_admin_extra).
-author('badlop@process-one.net').

-behaviour(gen_mod).

-export([start/2, stop/1,
	 %% Node
	 compile/1,
	 load_config/1,
	 get_cookie/0,
	 remove_node/1,
	 export2odbc/2,
	 %% Accounts
	 set_password/3,
	 delete_older_users/1,
	 delete_older_messages/1,
	 ban_account/3,
	 num_active_users/2,
	 %% Sessions
	 num_resources/2,
	 resource_num/3,
	 kick_session/4,
	 status_num/2, status_num/1,
	 status_list/2, status_list/1,
	 %% Vcard
	 set_nickname/3,
	 get_vcard/3,
	 get_vcard/4,
	 set_vcard/4,
	 set_vcard/5,
	 %% Roster
	 add_rosteritem/7,
	 delete_rosteritem/4,
	 process_rosteritems/5,
	 get_roster/2,
	 push_roster/3,
	 push_roster_all/1,
	 push_alltoall/2,
	 %% mod_shared_roster
	 srg_create/5,
	 srg_delete/2,
	 srg_list/1,
	 srg_get_info/2,
	 srg_get_members/2,
	 srg_user_add/4,
	 srg_user_del/4,
	 %% Stanza
	 send_message/4,
	 %% Stats
	 stats/1, stats/2
	]).

-include("ejabberd.hrl").
-include("ejabberd_commands.hrl").
-include("mod_roster.hrl").
-include("jlib.hrl").

%% Copied from ejabberd_sm.erl
-record(session, {sid, usr, us, priority, info}).


%%%
%%% gen_mod
%%%

start(_Host, _Opts) ->
    ejabberd_commands:register_commands(commands()).

stop(_Host) ->
    ejabberd_commands:unregister_commands(commands()).


%%%
%%% Register commands
%%%

commands() ->
    Vcard1FieldsString = "Some vcard field names in get/set_vcard are:\n"
	" FN		- Full Name\n"
	" NICKNAME	- Nickname\n"
	" BDAY		- Birthday\n"
	" TITLE		- Work: Position\n",
    " ROLE		- Work: Role",

    Vcard2FieldsString = "Some vcard field names and subnames in get/set_vcard2 are:\n"
	" N FAMILY	- Family name\n"
	" N GIVEN	- Given name\n"
	" N MIDDLE	- Middle name\n"
	" ADR CTRY	- Address: Country\n"
	" ADR LOCALITY	- Address: City\n"
	" EMAIL USERID	- E-Mail Address\n"
	" ORG ORGNAME	- Work: Company\n"
	" ORG ORGUNIT	- Work: Department",

    VcardXEP = "For a full list of vCard fields check XEP-0054: vcard-temp at "
	"http://www.xmpp.org/extensions/xep-0054.html",

    [
     #ejabberd_commands{name = compile, tags = [erlang],
			desc = "Recompile and reload Erlang source code file",
			module = ?MODULE, function = compile,
			args = [{file, string}],
			result = {res, rescode}},
     #ejabberd_commands{name = load_config, tags = [server],
			desc = "Load ejabberd configuration file",
			module = ?MODULE, function = load_config,
			args = [{file, string}],
			result = {res, rescode}},
     #ejabberd_commands{name = get_cookie, tags = [erlang],
			desc = "Get the Erlang cookie of this node",
			module = ?MODULE, function = get_cookie,
			args = [],
			result = {cookie, string}},
     #ejabberd_commands{name = remove_node, tags = [erlang],
			desc = "Remove an ejabberd node from Mnesia clustering config",
			module = ?MODULE, function = remove_node,
			args = [{node, string}],
			result = {res, rescode}},
     #ejabberd_commands{name = export2odbc, tags = [mnesia],
			desc = "Export Mnesia tables to files in directory",
			module = ?MODULE, function = export2odbc,
			args = [{host, string}, {path, string}],
			result = {res, rescode}},

     #ejabberd_commands{name = num_active_users, tags = [accounts, stats],
			desc = "Get number of users active in the last days",
			module = ?MODULE, function = num_active_users,
			args = [{host, string}, {days, integer}],
			result = {users, integer}},
     #ejabberd_commands{name = delete_older_users, tags = [accounts, purge],
			desc = "Delete users that didn't log in last days",
			module = ?MODULE, function = delete_older_users,
			args = [{days, integer}],
			result = {res, restuple}},
     #ejabberd_commands{name = delete_older_messages, tags = [purge],
			desc = "Delete offline messages older than days",
			module = ?MODULE, function = delete_older_messages,
			args = [{days, integer}],
			result = {res, rescode}},

     #ejabberd_commands{name = check_account, tags = [accounts],
			desc = "Check if an acount exists or not",
			module = ejabberd_auth, function = is_user_exists,
			args = [{user, string}, {host, string}],
			result = {res, rescode}},
     #ejabberd_commands{name = check_password, tags = [accounts],
			desc = "Check if a password is correct",
			module = ejabberd_auth, function = check_password,
			args = [{user, string}, {host, string}, {password, string}],
			result = {res, rescode}},
     #ejabberd_commands{name = change_password, tags = [accounts],
			desc = "Change the password of an account",
			module = ?MODULE, function = set_password,
			args = [{user, string}, {host, string}, {newpass, string}],
			result = {res, rescode}},
     #ejabberd_commands{name = ban_account, tags = [accounts],
			desc = "Ban an account: kick sessions and set random password",
			module = ?MODULE, function = ban_account,
			args = [{user, string}, {host, string}, {reason, string}],
			result = {res, rescode}},

     #ejabberd_commands{name = num_resources, tags = [session],
			desc = "Get the number of resources of a user",
			module = ?MODULE, function = num_resources,
			args = [{user, string}, {host, string}],
			result = {resources, integer}},
     #ejabberd_commands{name = resource_num, tags = [session],
			desc = "Resource string of a session number",
			module = ?MODULE, function = resource_num,
			args = [{user, string}, {host, string}, {num, integer}],
			result = {resource, string}},
     #ejabberd_commands{name = kick_session, tags = [session],
			desc = "Kick a user session",
			module = ?MODULE, function = kick_session,
			args = [{user, string}, {host, string}, {resource, string}, {reason, string}],
			result = {res, rescode}},
     #ejabberd_commands{name = status_num_host, tags = [session, stats],
			desc = "Number of logged users with this status in host",
			module = ?MODULE, function = status_num,
			args = [{host, string}, {status, string}],
			result = {users, integer}},
     #ejabberd_commands{name = status_num, tags = [session, stats],
			desc = "Number of logged users with this status",
			module = ?MODULE, function = status_num,
			args = [{status, string}],
			result = {users, integer}},
     #ejabberd_commands{name = status_list_host, tags = [session],
			desc = "List of users logged in host with their statuses",
			module = ?MODULE, function = status_list,
			args = [{host, string}, {status, string}],
			result = {users, {list,
					  {userstatus, {tuple, [
								{user, string},
								{host, string},
								{resource, string},
								{priority, integer},
								{status, string}
							       ]}}
					 }}},
     #ejabberd_commands{name = status_list, tags = [session],
			desc = "List of logged users with this status",
			module = ?MODULE, function = status_list,
			args = [{status, string}],
			result = {users, {list,
					  {userstatus, {tuple, [
								{user, string},
								{host, string},
								{resource, string},
								{priority, integer},
								{status, string}
							       ]}}
					 }}},

     #ejabberd_commands{name = set_nickname, tags = [vcard],
			desc = "Set nickname in a user's vcard",
			module = ?MODULE, function = set_nickname,
			args = [{user, string}, {host, string}, {nickname, string}],
			result = {res, rescode}},

     #ejabberd_commands{name = get_vcard, tags = [vcard],
			desc = "Get content from a vCard field",
			longdesc = Vcard1FieldsString ++ "\n" ++ Vcard2FieldsString ++ "\n\n" ++ VcardXEP,
			module = ?MODULE, function = get_vcard,
			args = [{user, string}, {host, string}, {name, string}],
			result = {content, string}},
     #ejabberd_commands{name = get_vcard2, tags = [vcard],
			desc = "Get content from a vCard field",
			longdesc = Vcard2FieldsString ++ "\n\n" ++ Vcard1FieldsString ++ "\n" ++ VcardXEP,
			module = ?MODULE, function = get_vcard,
			args = [{user, string}, {host, string}, {name, string}, {subname, string}],
			result = {content, string}},
     #ejabberd_commands{name = set_vcard, tags = [vcard],
			desc = "Set content in a vCard field",
			longdesc = Vcard1FieldsString ++ "\n" ++ Vcard2FieldsString ++ "\n\n" ++ VcardXEP,
			module = ?MODULE, function = set_vcard,
			args = [{user, string}, {host, string}, {name, string}, {content, string}],
			result = {res, rescode}},
     #ejabberd_commands{name = set_vcard2, tags = [vcard],
			desc = "Set content in a vCard subfield",
			longdesc = Vcard2FieldsString ++ "\n\n" ++ Vcard1FieldsString ++ "\n" ++ VcardXEP,
			module = ?MODULE, function = set_vcard2,
			args = [{user, string}, {host, string}, {name, string}, {subname, string}, {content, string}],
			result = {res, rescode}},

     #ejabberd_commands{name = add_rosteritem, tags = [roster],
			desc = "Add an item to a user's roster",
			module = ?MODULE, function = add_rosteritem,
			args = [{localuser, string}, {localserver, string},
				{user, string}, {server, string},
				{nick, string}, {group, string},
				{subs, string}],
			result = {res, rescode}},
     %%{"", "subs= none, from, to or both"},
     %%{"", "example: add-roster peter localhost mike server.com MiKe Employees both"},
     %%{"", "will add mike@server.com to peter@localhost roster"},
     #ejabberd_commands{name = delete_rosteritem, tags = [roster],
			desc = "Delete an item from a user's roster",
			module = ?MODULE, function = delete_rosteritem,
			args = [{localuser, string}, {localserver, string},
				{user, string}, {server, string}],
			result = {res, rescode}},
     #ejabberd_commands{name = process_rosteritems, tags = [roster],
			desc = "List or delete rosteritems that match filtering options",
			longdesc = "Explanation of each argument:\n"
			" - action: what to do with each rosteritem that "
			"matches all the filtering options\n"
			" - subs: subscription type\n"
			" - asks: pending subscription\n"
			" - users: the JIDs of the local user\n"
			" - contacts: the JIDs of the contact in the roster\n"
			"\n"
			"Allowed values in the arguments:\n"
			"  ACTION = list | delete\n"
			"  SUBS = SUB[:SUB]* | any\n"
			"  SUB = none | from | to | both\n"
			"  ASKS = ASK[:ASK]* | any\n"
			"  ASK = none | out | in\n"
			"  USERS = JID[:JID]* | any\n"
			"  CONTACTS = JID[:JID]* | any\n"
			"  JID = characters valid in a JID, and can use the "
			"globs: *, ? and [...]\n"
			"\n"
			"This example will list roster items with subscription "
			"'none', 'from' or 'to' that have any ask property, of "
			"local users which JID is in the virtual host "
			"'example.org' and that the contact JID is either a "
			"bare server name (without user part) or that has a "
			"user part and the server part contains the word 'icq'"
			":\n  list none:from:to any *@example.org *:*@*icq*",
			module = ?MODULE, function = process_rosteritems,
			args = [{action, string}, {subs, string},
				{asks, string}, {users, string},
				{contacts, string}],
			result = {res, rescode}},
     #ejabberd_commands{name = get_roster, tags = [roster],
			desc = "Get roster of a local user",
			module = ?MODULE, function = get_roster,
			args = [{user, string}, {host, string}],
			result = {contacts, {list, {contact, {tuple, [
								      {jid, string},
								      {nick, string},
								      {group, string}
								     ]}}}}},
     #ejabberd_commands{name = push_roster, tags = [roster],
			desc = "Push template roster from file to a user",
			module = ?MODULE, function = push_roster,
			args = [{file, string}, {user, string}, {host, string}],
			result = {res, rescode}},
     #ejabberd_commands{name = push_roster_all, tags = [roster],
			desc = "Push template roster from file to all those users",
			module = ?MODULE, function = push_roster_all,
			args = [{file, string}],
			result = {res, rescode}},
     #ejabberd_commands{name = push_alltoall, tags = [roster],
			desc = "Add all the users to all the users of Host in Group",
			module = ?MODULE, function = push_alltoall,
			args = [{host, string}, {group, string}],
			result = {res, rescode}},

     #ejabberd_commands{name = srg_create, tags = [shared_roster_group],
			desc = "Create a Shared Roster Group",
			module = ?MODULE, function = srg_create,
			args = [{group, string}, {host, string},
				{name, string}, {description, string}, {display, string}],
			result = {res, rescode}},
     #ejabberd_commands{name = srg_delete, tags = [shared_roster_group],
			desc = "Delete a Shared Roster Group",
			module = ?MODULE, function = srg_delete,
			args = [{group, string}, {host, string}],
			result = {res, rescode}},
     #ejabberd_commands{name = srg_list, tags = [shared_roster_group],
			desc = "List the Shared Roster Groups in Host",
			module = ?MODULE, function = srg_list,
			args = [{host, string}],
			result = {groups, {list, {id, string}}}},
     #ejabberd_commands{name = srg_get_info, tags = [shared_roster_group],
			desc = "Get info of a Shared Roster Group",
			module = ?MODULE, function = srg_get_info,
			args = [{group, string}, {host, string}],
			result = {informations, {list, {information, {tuple, [{key, string}, {value, string}]}}}}},
     #ejabberd_commands{name = srg_get_members, tags = [shared_roster_group],
			desc = "Get members of a Shared Roster Group",
			module = ?MODULE, function = srg_get_members,
			args = [{group, string}, {host, string}],
			result = {members, {list, {member, string}}}},
     #ejabberd_commands{name = srg_user_add, tags = [shared_roster_group],
			desc = "Add the JID user@server to the Shared Roster Group",
			module = ?MODULE, function = srg_user_add,
			args = [{user, string}, {host, string}, {group, string}, {host, string}],
			result = {res, rescode}},
     #ejabberd_commands{name = srg_user_del, tags = [shared_roster_group],
			desc = "Delete this JID user@host from the Shared Roster Group",
			module = ?MODULE, function = srg_user_del,
			args = [{user, string}, {host, string}, {group, string}, {grouphost, string}],
			result = {res, rescode}},

     #ejabberd_commands{name = send_message, tags = [stanza],
			desc = "Send a headline message to a local or remote bare of full JID",
			module = ?MODULE, function = send_message,
			args = [{from, string}, {to, string},
				{subject, string}, {body, string}],
			result = {res, rescode}},

     #ejabberd_commands{name = stats, tags = [stats],
			desc = "Get statistical value: registeredusers onlineusers onlineusersnode uptimeseconds",
			module = ?MODULE, function = stats,
			args = [{name, string}],
			result = {stat, integer}},
     #ejabberd_commands{name = stats_host, tags = [stats],
			desc = "Get statistical value for this host: registeredusers onlineusers",
			module = ?MODULE, function = stats,
			args = [{name, string}, {host, string}],
			result = {stat, integer}}
    ].


%%%
%%% Node
%%%

compile(File) ->
    case compile:file(File) of
	ok -> ok;
	_ -> error
    end.

load_config(Path) ->
    ok = ejabberd_config:load_file(Path).

get_cookie() ->
    atom_to_list(erlang:get_cookie()).

remove_node(Node) ->
    mnesia:del_table_copy(schema, list_to_atom(Node)),
    ok.

export2odbc(Host, Directory) ->
    Tables = [
	      {export_last, last},
	      {export_offline, offline},
	      {export_passwd, passwd},
	      {export_private_storage, private_storage},
	      {export_roster, roster},
	      {export_vcard, vcard},
	      {export_vcard_search, vcard_search}],
    Export = fun({TableFun, Table}) ->
		     Filename = filename:join([Directory, atom_to_list(Table)++".txt"]),
		     io:format("Trying to export Mnesia table '~p' on Host '~s' to file '~s'~n", [Table, Host, Filename]),
		     Res = (catch ejd2odbc:TableFun(Host, Filename)),
		     io:format("  Result: ~p~n", [Res])
	     end,
    lists:foreach(Export, Tables),
    ok.


%%%
%%% Accounts
%%%

set_password(User, Host, Password) ->
    case ejabberd_auth:set_password(User, Host, Password) of
	{atomic, ok} ->
	    ok;
	_ ->
	    error
    end.

num_active_users(Host, Days) ->
    list_last_activity(Host, true, Days).

%% Code based on ejabberd/src/web/ejabberd_web_admin.erl
list_last_activity(Host, Integral, Days) ->
    {MegaSecs, Secs, _MicroSecs} = now(),
    TimeStamp = MegaSecs * 1000000 + Secs,
    TS = TimeStamp - Days * 86400,
    case catch mnesia:dirty_select(
		 last_activity, [{{last_activity, {'_', Host}, '$1', '_'},
				  [{'>', '$1', TS}],
				  [{'trunc', {'/',
					      {'-', TimeStamp, '$1'},
					      86400}}]}]) of
							      {'EXIT', _Reason} ->
		 [];
	       Vals ->
		 Hist = histogram(Vals, Integral),
		 if
		     Hist == [] ->
			 0;
		     true ->
			 Left = Days - length(Hist),
			 Tail = if
				    Integral ->
					lists:duplicate(Left, lists:last(Hist));
				    true ->
					lists:duplicate(Left, 0)
				end,
			 lists:nth(Days, Hist ++ Tail)
		 end
	 end.
histogram(Values, Integral) ->
    histogram(lists:sort(Values), Integral, 0, 0, []).
histogram([H | T], Integral, Current, Count, Hist) when Current == H ->
    histogram(T, Integral, Current, Count + 1, Hist);
histogram([H | _] = Values, Integral, Current, Count, Hist) when Current < H ->
    if
	Integral ->
	    histogram(Values, Integral, Current + 1, Count, [Count | Hist]);
	true ->
	    histogram(Values, Integral, Current + 1, 0, [Count | Hist])
    end;
histogram([], _Integral, _Current, Count, Hist) ->
    if
	Count > 0 ->
	    lists:reverse([Count | Hist]);
	true ->
	    lists:reverse(Hist)
    end.



delete_older_users(Days) ->
    {removed, N, UR} = delete_older_users(Days),
    {ok, io_lib:format("Deleted ~p users: ~p", [N, UR])}.

delete_older_messages(Days) ->
    mod_offline:remove_old_messages(list_to_integer(Days)),
    ok.

%%
%% Ban account

ban_account(User, Host, ReasonText) ->
    Reason = prepare_reason(ReasonText),
    kick_sessions(User, Host, Reason),
    set_random_password(User, Host, Reason),
    ok.

kick_sessions(User, Server, Reason) ->
    lists:map(
      fun(Resource) ->
	      kick_this_session(User, Server, Resource, Reason)
      end,
      get_resources(User, Server)).

get_resources(User, Server) ->
    lists:map(
      fun(Session) ->
	      element(3, Session#session.usr)
      end,
      get_sessions(User, Server)).

get_sessions(User, Server) ->
    LUser = jlib:nodeprep(User),
    LServer = jlib:nameprep(Server),
    Sessions =  mnesia:dirty_index_read(session, {LUser, LServer}, #session.us),
    true = is_list(Sessions),
    Sessions.

set_random_password(User, Server, Reason) ->
    NewPass = build_random_password(Reason),
    set_password_auth(User, Server, NewPass).

build_random_password(Reason) ->
    Date = jlib:timestamp_to_iso(calendar:universal_time()),
    RandomString = randoms:get_string(),
    "BANNED_ACCOUNT--" ++ Date ++ "--" ++ RandomString ++ "--" ++ Reason.

set_password_auth(User, Server, Password) ->
    {atomic, ok} = ejabberd_auth:set_password(User, Server, Password).

prepare_reason([]) ->
    "Kicked by administrator";
prepare_reason([Reason]) ->
    Reason;
prepare_reason(Reason) when is_list(Reason) ->
    Reason;
prepare_reason(StringList) ->
    string:join(StringList, "_").


%%%
%%% Sessions
%%%

num_resources(User, Host) ->
    length(ejabberd_sm:get_user_resources(User, Host)).

resource_num(User, Host, Num) ->
    Resources = ejabberd_sm:get_user_resources(User, Host),
    case (0<Num) and (Num=<length(Resources)) of
	true ->
	    lists:nth(Num, Resources);
	false ->
	    lists:flatten(io_lib:format("Error: Wrong resource number: ~p", [Num]))
    end.

kick_session(User, Server, Resource, ReasonText) ->
    kick_this_session(User, Server, Resource, prepare_reason(ReasonText)),
    ok.

kick_this_session(User, Server, Resource, Reason) ->
    ejabberd_router:route(
      jlib:make_jid("", "", ""),
      jlib:make_jid(User, Server, Resource),
      {xmlelement, "broadcast", [], [{exit, Reason}]}).


status_num(Host, Status) ->
    length(get_status_list(Host, Status)).
status_num(Status) ->
    status_num("all", Status).
status_list(Host, Status) ->
    Res = get_status_list(Host, Status),
    [{U, S, R, P, St} || {U, S, R, P, St} <- Res].
status_list(Status) ->
    status_list("all", Status).


get_status_list(Host, Status_required) ->
    %% Get list of all logged users
    Sessions = ejabberd_sm:dirty_get_my_sessions_list(),
    %% Reformat the list
    Sessions2 = [ {Session#session.usr, Session#session.sid, Session#session.priority} || Session <- Sessions],
    Fhost = case Host of
		"all" ->
		    %% All hosts are requested, so dont filter at all
		    fun(_, _) -> true end;
		_ ->
		    %% Filter the list, only Host is interesting
		    fun(A, B) -> A == B end
	    end,
    Sessions3 = [ {Pid, Server, Priority} || {{_User, Server, _Resource}, {_, Pid}, Priority} <- Sessions2, apply(Fhost, [Server, Host])],
    %% For each Pid, get its presence
    Sessions4 = [ {ejabberd_c2s:get_presence(Pid), Server, Priority} || {Pid, Server, Priority} <- Sessions3],
    %% Filter by status
    Fstatus = case Status_required of
		  "all" ->
		      fun(_, _) -> true end;
		  _ ->
		      fun(A, B) -> A == B end
	      end,
    [{User, Server, Resource, Priority, stringize(Status_text)}
     || {{User, Resource, Status, Status_text}, Server, Priority} <- Sessions4,
	apply(Fstatus, [Status, Status_required])].

%% Make string more print-friendly
stringize(String) ->
    %% Replace newline characters with other code
    element(2, regexp:gsub(String, "\n", "\\n")).


%%%
%%% Vcard
%%%

set_nickname(User, Host, Nickname) ->
    R = mod_vcard:process_sm_iq(
	  {jid, User, Host, "", User, Host, ""},
	  {jid, User, Host, "", User, Host, ""},
	  {iq, "", set, "", "en",
	   {xmlelement, "vCard",
	    [{"xmlns", "vcard-temp"}], [
					{xmlelement, "NICKNAME", [], [{xmlcdata, Nickname}]}
				       ]
	   }}),
    case R of
	{iq, [], result, [], _L, []} ->
	    ok;
	_ ->
	    error
    end.

get_vcard(User, Host, Name) ->
    get_vcard_content(User, Host, [Name]).

get_vcard(User, Host, Name, Subname) ->
    get_vcard_content(User, Host, [Name, Subname]).

set_vcard(User, Host, Name, Content) ->
    set_vcard_content(User, Host, [Name], Content).

set_vcard(User, Host, Name, Subname, Content) ->
    set_vcard_content(User, Host, [Name, Subname], Content).


%%
%% Internal vcard

get_vcard_content(User, Server, Data) ->
    [{_, Module, Function, _Opts}] = ets:lookup(sm_iqtable, {?NS_VCARD, Server}),
    JID = jlib:make_jid(User, Server, ""),
    IQ = #iq{type = get, xmlns = ?NS_VCARD},
    IQr = Module:Function(JID, JID, IQ),
    case IQr#iq.sub_el of
	[A1] ->
	    case get_vcard(Data, A1) of
		false -> "Error: no_value";
		Elem -> xml:get_tag_cdata(Elem)
	    end;
	[] ->
	    "Error: no_vcard"
    end.

get_vcard([Data1, Data2], A1) ->
    case xml:get_subtag(A1, Data1) of
    	false -> false;
	A2 -> get_vcard([Data2], A2)
    end;

get_vcard([Data], A1) ->
    xml:get_subtag(A1, Data).

set_vcard_content(User, Server, Data, Content) ->
    [{_, Module, Function, _Opts}] = ets:lookup(sm_iqtable, {?NS_VCARD, Server}),
    JID = jlib:make_jid(User, Server, ""),
    IQ = #iq{type = get, xmlns = ?NS_VCARD},
    IQr = Module:Function(JID, JID, IQ),

    %% Get old vcard
    A4 = case IQr#iq.sub_el of
	     [A1] ->
		 {_, _, _, A2} = A1,
		 update_vcard_els(Data, Content, A2);
	     [] ->
		 update_vcard_els(Data, Content, [])
	 end,

    %% Build new vcard
    SubEl = {xmlelement, "vCard", [{"xmlns","vcard-temp"}], A4},
    IQ2 = #iq{type=set, sub_el = SubEl},

    Module:Function(JID, JID, IQ2),
    ok.

update_vcard_els(Data, Content, Els1) ->
    Els2 = lists:keysort(2, Els1),
    [Data1 | Data2] = Data,
    NewEl = case Data2 of
		[] ->
		    {xmlelement, Data1, [], [{xmlcdata,Content}]};
		[D2] ->
		    OldEl = case lists:keysearch(Data1, 2, Els2) of
				{value, A} -> A;
				false -> {xmlelement, Data1, [], []}
			    end,
		    {xmlelement, _, _, ContentOld1} = OldEl,
		    Content2 = [{xmlelement, D2, [], [{xmlcdata,Content}]}],
		    ContentOld2 = lists:keysort(2, ContentOld1),
		    ContentOld3 = lists:keydelete(D2, 2, ContentOld2),
		    ContentNew = lists:keymerge(2, Content2, ContentOld3),
		    {xmlelement, Data1, [], ContentNew}
	    end,
    Els3 = lists:keydelete(Data1, 2, Els2),
    lists:keymerge(2, [NewEl], Els3).


%%%
%%% Roster
%%%

add_rosteritem(LocalUser, LocalServer, User, Server, Nick, Group, Subs) ->
    case add_rosteritem(LocalUser, LocalServer, User, Server, Nick, Group, list_to_atom(Subs), []) of
	{atomic, ok} ->
	    push_roster_item(LocalUser, LocalServer, User, Server, {add, Nick, Subs, Group}),
	    ok;
	_ ->
	    error
    end.

add_rosteritem(LU, LS, User, Server, Nick, Group, Subscription, Xattrs) ->
    subscribe(LU, LS, User, Server, Nick, Group, Subscription, Xattrs).

subscribe(LU, LS, User, Server, Nick, Group, Subscription, Xattrs) ->
    mnesia:transaction(
      fun() ->
	      mnesia:write({roster,
			    {LU,LS,{User,Server,[]}}, % uj
			    {LU,LS},                  % user
			    {User,Server,[]},      % jid
			    Nick,                  % name: "Mom", []
			    Subscription,  % subscription: none, to=you see him, from=he sees you, both
			    none,          % ask: out=send request, in=somebody requests you, none
			    [Group],       % groups: ["Family"]
			    Xattrs,        % xattrs: [{"category","conference"}]
			    []             % xs: []
			   })
      end).

delete_rosteritem(LocalUser, LocalServer, User, Server) ->
    case unsubscribe(LocalUser, LocalServer, User, Server) of
	{atomic, ok} ->
	    push_roster_item(LocalUser, LocalServer, User, Server, remove),
	    ok;
	_  ->
	    error
    end.

unsubscribe(LU, LS, User, Server) ->
    mnesia:transaction(
      fun() ->
              mnesia:delete({roster, {LU, LS, {User, Server, []}}})
      end).


%% -----------------------------
%% Get Roster
%% -----------------------------

get_roster(User, Server) ->
    {ok, Roster} = get_roster2(User, Server),
    make_roster_xmlrpc(Roster).

get_roster2(User, Server) ->
    Modules = gen_mod:loaded_modules(Server),
    Roster = case lists:member(mod_roster, Modules) of
		 true ->
		     mod_roster:get_user_roster([], {User, Server});
		 false ->
		     case lists:member(mod_roster_odbc, Modules) of
			 true ->
			     mod_roster_odbc:get_user_roster([], {User, Server});
			 false ->
			     {error, "Neither mod_roster or mod_roster_odbc are enabled"}
		     end
	     end,
    {ok, Roster}.

%% Note: if a contact is in several groups, the contact is returned
%% several times, each one in a different group.
make_roster_xmlrpc(Roster) ->
    lists:foldl(
      fun(Item, Res) ->
	      JIDS = jlib:jid_to_string(Item#roster.jid),
	      Nick = Item#roster.name,
	      Groups = case Item#roster.groups of
			   [] -> [""];
			   Gs -> Gs
		       end,
	      ItemsX = [{JIDS, Nick, Group}
			|| Group <- Groups],
	      ItemsX ++ Res
      end,
      [],
      Roster).


%%-----------------------------
%% Push Roster from file
%%-----------------------------

push_roster(File, User, Server) ->
    {ok, [Roster]} = file:consult(File),
    subscribe_roster({User, Server, "", User}, Roster).

push_roster_all(File) ->
    {ok, [Roster]} = file:consult(File),
    subscribe_all(Roster).

subscribe_all(Roster) ->
    subscribe_all(Roster, Roster).
subscribe_all([], _) ->
    ok;
subscribe_all([User1 | Users], Roster) ->
    subscribe_roster(User1, Roster),
    subscribe_all(Users, Roster).

subscribe_roster(_, []) ->
    ok;
%% Do not subscribe a user to itself
subscribe_roster({Name, Server, Group, Nick}, [{Name, Server, _, _} | Roster]) ->
    subscribe_roster({Name, Server, Group, Nick}, Roster);
%% Subscribe Name2 to Name1
subscribe_roster({Name1, Server1, Group1, Nick1}, [{Name2, Server2, Group2, Nick2} | Roster]) ->
    subscribe(Name1, Server1, Name2, Server2, Nick2, Group2, both, []),
    subscribe_roster({Name1, Server1, Group1, Nick1}, Roster).

push_alltoall(S, G) ->
    Users = ejabberd_auth:get_vh_registered_users(S),
    Users2 = build_list_users(G, Users, []),
    subscribe_all(Users2),
    ok.

build_list_users(_Group, [], Res) ->
    Res;
build_list_users(Group, [{User, Server}|Users], Res) ->
    build_list_users(Group, Users, [{User, Server, Group, User}|Res]).

%% @spec(LU, LS, U, S, Action) -> ok
%%       Action = {add, Nick, Subs, Group} | remove
%% @doc Push to the roster of account LU@LS the contact U@S.
%% The specific action to perform is defined in Action.
push_roster_item(LU, LS, U, S, Action) ->
    lists:foreach(fun(R) ->
			  push_roster_item(LU, LS, R, U, S, Action)
		  end, ejabberd_sm:get_user_resources(LU, LS)).

push_roster_item(LU, LS, R, U, S, Action) ->
    Item = build_roster_item(U, S, Action),
    ResIQ = build_iq_roster_push(Item),
    LJID = jlib:make_jid(LU, LS, R),
    ejabberd_router:route(LJID, LJID, ResIQ).

build_roster_item(U, S, {add, Nick, Subs, Group}) ->
    {xmlelement, "item",
     [{"jid", jlib:jid_to_string(jlib:make_jid(U, S, ""))},
      {"name", Nick},
      {"subscription", Subs}],
     [{xmlelement, "group", [], [{xmlcdata, Group}]}]
    };
build_roster_item(U, S, remove) ->
    {xmlelement, "item",
     [{"jid", jlib:jid_to_string(jlib:make_jid(U, S, ""))},
      {"subscription", "remove"}],
     []
    }.

build_iq_roster_push(Item) ->
    {xmlelement, "iq",
     [{"type", "set"}, {"id", "push"}],
     [{xmlelement, "query",
       [{"xmlns", ?NS_ROSTER}],
       [Item]
      }
     ]
    }.


%%%
%%% Shared Roster Groups
%%%

srg_create(Group, Host, Name, Description, Display) ->
    Opts = [{name, Name}, {displayed_groups, [Display]}, {description, Description}],
    {atomic, ok} = mod_shared_roster:create_group(Host, Group, Opts),
    ok.

srg_delete(Group, Host) ->
    {atomic, ok} = mod_shared_roster:delete_group(Host, Group),
    ok.

srg_list(Host) ->
    lists:sort(mod_shared_roster:list_groups(Host)).

srg_get_info(Group, Host) ->
    Opts = mod_shared_roster:get_group_opts(Host,Group),
    [{io_lib:format("~p", [Title]),
      io_lib:format("~p", [Value])} || {Title, Value} <- Opts].

srg_get_members(Group, Host) ->
    Members = mod_shared_roster:get_group_explicit_users(Host,Group),
    [jlib:jid_to_string(jlib:make_jid(MUser, MServer, ""))
     || {MUser, MServer} <- Members].

srg_user_add(User, Server, Group, Host) ->
    {atomic, ok} = mod_shared_roster:add_user_to_group(Host, {User, Server}, Group),
    ok.

srg_user_del(User, Host, Group, GroupHost) ->
    {atomic, ok} = mod_shared_roster:remove_user_from_group(GroupHost, {User, Host}, Group),
    ok.


%%%
%%% Stanza
%%%

%% @doc Send a message to a Jabber account.
%% If a resource was specified in the JID,
%% the message is sent only to that specific resource.
%% If no resource was specified in the JID,
%% and the user is remote or local but offline,
%% the message is sent to the bare JID.
%% If the user is local and is online in several resources,
%% the message is sent to all its resources.
send_message(FromJIDString, ToJIDString, Subject, Body) ->
    FromJID = jlib:string_to_jid(FromJIDString),
    ToJID = jlib:string_to_jid(ToJIDString),
    ToUser = ToJID#jid.user,
    ToServer = ToJID#jid.server,
    case ToJID#jid.resource of
	"" ->
	    send_message(FromJID, ToUser, ToServer, Subject, Body);
	Resource ->
	    send_message(FromJID, ToUser, ToServer, Resource, Subject, Body)
    end.

send_message(FromJID, ToUser, ToServer, Subject, Body) ->
    case ejabberd_sm:get_user_resources(ToUser, ToServer) of
	[] ->
	    send_message(FromJID, ToUser, ToServer, "", Subject, Body);
	ToResources ->
	    lists:foreach(
	      fun(ToResource) ->
		      send_message(FromJID, ToUser, ToServer, ToResource, Subject, Body)
	      end,
	      ToResources)
    end.

send_message(FromJID, ToU, ToS, ToR, Subject, Body) ->
    MPacket = build_send_message(Subject, Body),
    ToJID = jlib:make_jid(ToU, ToS, ToR),
    ejabberd_router:route(FromJID, ToJID, MPacket).

build_send_message(Subject, Body) ->
    {xmlelement, "message",
     [{"type", "headline"}],
     [{xmlelement, "subject", [], [{xmlcdata, Subject}]},
      {xmlelement, "body", [], [{xmlcdata, Body}]}
     ]
    }.


%%%
%%% Stats
%%%

stats(Name) ->
    case Name of
	"uptimeseconds" -> trunc(element(1, erlang:statistics(wall_clock))/1000);
	"registeredusers" -> mnesia:table_info(passwd, size);
	"onlineusersnode" -> length(ejabberd_sm:dirty_get_my_sessions_list());
	"onlineusers" -> length(ejabberd_sm:dirty_get_sessions_list())
    end.

stats(Name, Host) ->
    case Name of
	"registeredusers" -> length(ejabberd_auth:get_vh_registered_users(Host));
	"onlineusers" -> length(ejabberd_sm:get_vh_session_list(Host))
    end.



%%-----------------------------
%% Purge roster items
%%-----------------------------

process_rosteritems(ActionS, SubsS, AsksS, UsersS, ContactsS) ->
    Action = case ActionS of
		 "list" -> list;
		 "delete" -> delete
	     end,

    Subs = lists:foldl(
	     fun(any, _) -> [none, from, to, both];
		(Sub, Subs) -> [Sub | Subs]
	     end,
	     [],
	     [list_to_atom(S) || S <- string:tokens(SubsS, ":")]
	    ),

    Asks = lists:foldl(
	     fun(any, _) -> [none, out, in];
		(Ask, Asks) -> [Ask | Asks]
	     end,
	     [],
	     [list_to_atom(S) || S <- string:tokens(AsksS, ":")]
	    ),

    Users = lists:foldl(
	      fun("any", _) -> ["*", "*@*"];
		 (U, Us) -> [U | Us]
	      end,
	      [],
	      [S || S <- string:tokens(UsersS, ":")]
	     ),

    Contacts = lists:foldl(
		 fun("any", _) -> ["*", "*@*"];
		    (U, Us) -> [U | Us]
		 end,
		 [],
		 [S || S <- string:tokens(ContactsS, ":")]
		),

    case rosteritem_purge({Action, Subs, Asks, Users, Contacts}) of
	{atomic, ok} ->
	    ok;
	{error, Reason} ->
	    io:format("Error purging rosteritems: ~p~n", [Reason]),
	    error;
	{badrpc, Reason} ->
	    io:format("BadRPC purging rosteritems: ~p~n", [Reason]),
	    error
    end.

%% @spec ({Action::atom(), Subs::[atom()], Asks::[atom()], User::string(), Contact::string()}) -> {atomic, ok}
rosteritem_purge(Options) ->
    Num_rosteritems = mnesia:table_info(roster, size),
    io:format("There are ~p roster items in total.~n", [Num_rosteritems]),
    Key = mnesia:dirty_first(roster),
    ok = rip(Key, Options, {0, Num_rosteritems, 0, 0}),
    {atomic, ok}.

rip('$end_of_table', _Options, Counters) ->
    print_progress_line(Counters),
    ok;
rip(Key, Options, {Pr, NT, NV, ND}) ->
    Key_next = mnesia:dirty_next(roster, Key),
    {Action, _, _, _, _} = Options,
    ND2 = case decide_rip(Key, Options) of
	      true ->
		  apply_action(Action, Key),
		  ND+1;
	      false ->
		  ND
	  end,
    NV2 = NV+1,
    Pr2 = print_progress_line({Pr, NT, NV2, ND2}),
    rip(Key_next, Options, {Pr2, NT, NV2, ND2}).

apply_action(list, Key) ->
    {User, Server, JID} = Key,
    {RUser, RServer, _} = JID,
    io:format("Matches: ~s@~s ~s@~s~n", [User, Server, RUser, RServer]);
apply_action(delete, Key) ->
    apply_action(list, Key),
    mnesia:dirty_delete(roster, Key).

print_progress_line({Pr, NT, NV, ND}) ->
    Pr2 = trunc((NV/NT)*100),
    case Pr == Pr2 of
	true ->
	    ok;
	false ->
	    io:format("Progress ~p% - visited ~p - deleted ~p~n", [Pr2, NV, ND])
    end,
    Pr2.

decide_rip(Key, {_Action, Subs, Asks, User, Contact}) ->
    case catch mnesia:dirty_read(roster, Key) of
	[RI] ->
	    lists:member(RI#roster.subscription, Subs)
		andalso lists:member(RI#roster.ask, Asks)
		andalso decide_rip_jid(RI#roster.us, User)
		andalso decide_rip_jid(RI#roster.jid, Contact);
	_ ->
	    false
    end.

%% Returns true if the server of the JID is included in the servers
decide_rip_jid({UName, UServer, _UResource}, Match_list) ->
    decide_rip_jid({UName, UServer}, Match_list);
decide_rip_jid({UName, UServer}, Match_list) ->
    lists:any(
      fun(Match_string) ->
	      MJID = jlib:string_to_jid(Match_string),
	      MName = MJID#jid.luser,
	      MServer = MJID#jid.lserver,
	      Is_server = is_glob_match(UServer, MServer),
	      case MName of
		  [] when UName == [] ->
		      Is_server;
		  [] ->
		      false;
		  _ ->
		      Is_server
			  andalso is_glob_match(UName, MName)
	      end
      end,
      Match_list).

%% Copied from ejabberd-2.0.0/src/acl.erl
is_regexp_match(String, RegExp) ->
    case regexp:first_match(String, RegExp) of
	nomatch ->
	    false;
	{match, _, _} ->
	    true;
	{error, ErrDesc} ->
	    io:format(
	      "Wrong regexp ~p in ACL: ~p",
	      [RegExp, lists:flatten(regexp:format_error(ErrDesc))]),
	    false
    end.
is_glob_match(String, Glob) ->
    is_regexp_match(String, regexp:sh_to_awk(Glob)).