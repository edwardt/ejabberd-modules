%% @author author 
%% @copyright YYYY author.

%% @doc Supervisor for the user_presence_api application.

-module(user_presence_api_sup).

-behaviour(supervisor).

%% External exports
-export([start_link/0, upgrade/0]).

%% supervisor callbacks
-export([init/1]).

-define (APPNAME, 'user_presence_app').
-define(CHILD(I, Type, Args), {I, {I, start_link, Args}, permanent, 5000, Type, [I]}).

%% @spec start_link() -> ServerRet
%% @doc API for starting the supervisor.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% @spec upgrade() -> ok
%% @doc Add processes if necessary.
upgrade() ->
    {ok, {_, Specs}} = init([]),

    Old = sets:from_list(
            [Name || {Name, _, _, _} <- supervisor:which_children(?MODULE)]),
    New = sets:from_list([Name || {Name, _, _, _, _, _} <- Specs]),
    Kill = sets:subtract(Old, New),

    sets:fold(fun (Id, ok) ->
                      supervisor:terminate_child(?MODULE, Id),
                      supervisor:delete_child(?MODULE, Id),
                      ok
              end, ok, Kill),

    [supervisor:start_child(?MODULE, Spec) || Spec <- Specs],
    ok.

%% @spec init([]) -> SupervisorTree
%% @doc supervisor callback.
init([]) -> init([{"conf"},{"user_presence_api.config"}]);
init(Args) ->
    WebConfig = config(Args),
    Web = {webmachine_mochiweb,
          {webmachine_mochiweb, start, [WebConfig]},
           permanent, 5000, worker, [mochiweb_socket_server]},
    User = ?CHILD(user_presence_user, worker, Args),
    Users = ?CHILD(user_presence_users, worker, Args),
    Processes = [Web, 
                 User,
                 Users],
    {ok, { {one_for_one, 10, 10}, Processes} }.

%%
%% @doc return the priv dir
priv_dir(Mod) when is_atom(Mod)->
    priv_dir(code:priv_dir(Mod));
priv_dir({error, bad_name}) ->
    Ebin = filename:dirname(code:which(Mod)),
    filename:join(filename:dirname(Ebin), "priv").
priv_dir(Mod) -> Mod.

config(Args)->
    [{Path, File}] = Args,
    {ok, [ConfList]} = app_config_util:load_config(Path,File),
    {ok, Interface} = app_config_util:config_val(webmachine_inteface, ConfList,"eth0"),
    {ok, PublicIp} = try_get_ip(),
    {ok, Ip} = app_config_util:config_val(webmachine_ip, ConfList,"0.0.0.0"),
    {ok, Port} = app_config_util:config_val(webmachine_port, ConfList, 8000),
    {ok, Dispatch} = file:consult(filename:join([priv_dir(?APPNAME),
                                                 "dispatch.conf"])),
    [{ip, Ip},
     {port, Port},
     {log_dir, "priv/log"},
     {dispatch, Dispatch}].

try_get_ip()->
  Ips = get_all_interface_ip(),
  lists:dropwhile(fun(Ip) -> not_local(Ip) end,Ips).

%TODO get a better filter
not_local("127.0.0.1") -> false;
not_local(_) -> true.

get_all_interface_ip() ->
  {ok, List} = inet:getiflist(),  
  Ips = lists:map(fun (L)-> 
           get_interface_ip(L)   
        end,List).

get_interface_ip(Inteface) when is_list(Inteface) ->
  {ok, [addr, Ip]} = inet:ifget(L,[addr]),
  inet_parse:ntoa(Ip). 

