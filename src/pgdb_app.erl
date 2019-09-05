-module(pgdb_app).
-behaviour(application).

-export([start/2]).
-export([stop/1]).






%% =============================================================================
%% APPLICATION CALLBACKS
%% =============================================================================



start(_StartType, _StartArgs) ->
    {ok, Pools} = application:get_env(pgdb, pools),
    case pgdb_sup:start_link() of
        {ok, _} = OK ->
            %% The first time we get a connection there is a lag (we need to
            %% find out why, in the meantime we get the first connection during
            %% startup
            _ = [
                pgdb:return_connection(pgdb:get_connection(Pool))
                || {Pool, _} <- Pools
            ],
            OK;
        Error ->
            Error
    end.


stop(_State) ->
    ok.




%% =============================================================================
%% PRIVATE
%% =============================================================================
