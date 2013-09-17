%% @private
-module(ejabberd_rest_api_sup).
-behaviour(supervisor).

%% API.
-export([start_link/1]).

%% supervisor.
-export([init/1]).
-define (SERVER, ?MODULE).
%% API.

-spec start_link() -> {ok, pid()}.
start_link([]) -> 
	DefaultArgs = default_args();
	start_link(DefaultArgs);
start_link(Args) ->
	supervisor:start_link({local, ?SERVER}, ?MODULE, Args).

%% supervisor.

init(Args) ->
	Procs = [],
	{ok, {{one_for_one, 10, 10}, Procs}}.
