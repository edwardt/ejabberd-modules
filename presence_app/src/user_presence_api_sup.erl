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
    Processes = [Web],
    {ok, { {one_for_one, 10, 10}, Processes} }.

%%
%% @doc return the priv dir
priv_dir(Mod) ->
    case code:priv_dir(Mod) of
        {error, bad_name} ->
            Ebin = filename:dirname(code:which(Mod)),
            filename:join(filename:dirname(Ebin), "priv");
        PrivDir ->
            PrivDir
    end.

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

get_interface_ip(Interface) when is_list(Interface) ->
  {ok, [addr, Ip]} = inet:ifget(Interface,[addr]),
  inet_parse:ntoa(Ip). 

