%% @author author <author@example.com>
%% @copyright YYYY author.

%% @doc Supervisor for the presence_rest_api application.

-module(presence_rest_api_sup).
-author('author <author@example.com>').

-behaviour(supervisor).

%% External exports
-export([start_link/0, upgrade/0]).

%% supervisor callbacks
-export([init/1]).

-define(ConfPath,"priv").
-define(ConfFile, "spark_user_presence.config").
-define(SERVER, ?MODULE).

%% @spec start_link() -> ServerRet
%% @doc API for starting the supervisor.
start_link() -> start_link({?ConfPath, ?ConfFile}).
start_link(Args) ->
    error_logger:info_msg("Starting ~p supervisor with args ~p", [?MODULE, Args]),
    supervisor:start_link({local, ?SERVER}, ?MODULE, [Args]).


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

%% @spec init() -> SupervisorTree
init() -> init([]).

%% @spec init([]) -> SupervisorTree
%% @doc supervisor callback.
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
    {ok, Cwd} = app_config_util:cwd("priv"),
    {ok, log_dir} = app_config_util:config_val(log_dir, ConfList,"priv/log"),
    {ok, Dispatch} = file:consult(
			filename:join([Cwd,"dispatch.conf"])),

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


