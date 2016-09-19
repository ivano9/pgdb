%% =============================================================================
%%
%% pdbg: postgresql driver utils
%%
%% Copyright (c) 2016 Ngineo Limited t/a Leapsight. All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% =============================================================================

%% -----------------------------------------------------------------------------
%% @doc
%% This module provides and abstraction on top of the underlying 
%% Postgresql db driver and connection pooling mechanism.
%% It also provides the functionality to manage tenant schemas and run 
%% SQL queries.
%% In addition to supporting all underlying db driver query types, this module
%% also provides the match query type.
%% 
%% == Query Options ==
%% - on_error_abort : If set to true and only during a transaction (explicit 
%% via SQL commands or implict via the transaction/1 function) if any SQL 
%% statement returns and error, we will rollback and throw an exception. This 
%% is used internally in transaction/1 to be able to interrupt the execution 
%% of the statements within the transaction. However, transaction/1 catches it 
%% and returns an error. In case you issue an explicit transaction and 
%% on_error_abort is true, you will need to catch the exception.
%% @end
%% -----------------------------------------------------------------------------
-module(pgdb).
-include("pgdb.hrl").

-export([abort/1]).
-export([batch_query/2]).
-export([batch_query/3]).
-export([batch_query/4]).
-export([batch_query/5]).
-export([close/1]).
-export([create_schema/1]).
-export([create_schema/2]).
-export([drop_schema/1]).
-export([extended_query/2]).
-export([extended_query/3]).
-export([extended_query/4]).
-export([extended_query/5]).
-export([fetch_schema/1]).
-export([get_connection/1]).
-export([has_schema/1]).
-export([list_schemas/0]).
-export([lookup_schema/1]).
-export([match/3]).
-export([match/4]).
-export([match/5]).
-export([named_query/2]).
-export([open/1]).
-export([return_connection/1]).
-export([simple_query/1]).
-export([simple_query/2]).
-export([simple_query/3]).
-export([simple_query/4]).
-export([transaction/1]).
-export([transaction/2]).
-export([update_schema/2]).


-define(DEFAULT_ON_ERROR_ABORT, true).
-define(GET_CONN_RETRIES, 10).
-define(GET_CONN_RETRY_TIMEOUT, 1000).
-define(GET_CONN_TIMEOUT, 5000).
-define(QUERY_TIMEOUT, 5000).

-type options() ::  [option()].

-type option()  ::  {pool, atom()} 
                    | {on_error_abort, boolean()} % default: true 
                    | {max_rows_step, non_neg_integer()}
                    | {retry, boolean()} % default: false
                    | proplists:property().

-type connection() :: {Pool :: atom(), pgsql_connection:pgsql_connection()}.




%% ============================================================================
%% CONNECTION POOL CALLBACKS
%% ============================================================================



%% -----------------------------------------------------------------------------
%% @doc
%% Opens a new database connection. 
%% This function is called by the pool manager every time it needs a new 
%% connection. There is no need for you to use it directly.
%% @end
%% -----------------------------------------------------------------------------
-spec open(list()) -> {ok, pid()}.
open(Args) ->
    {pgsql_connection, Pid} = pgsql_connection:open(Args),
    {ok, Pid}.


%% -----------------------------------------------------------------------------
%% @doc
%% Closes a new database connection. 
%% This function is called by the pool manager every time it needs to close 
%% a connection. There is no need for you to use it directly.
%% @end
%% -----------------------------------------------------------------------------
-spec close(pid()) -> ok.
close(Pid) ->
    pgsql_connection:close({pgsql_connection, Pid}).


%% ============================================================================
%% CONNECTIONS
%% ============================================================================



abort(Reason) ->
    throw(Reason).


%% -----------------------------------------------------------------------------
%% @doc
%% Returns a connection to the underlying db from the pool. 
%% This is not required to perform queries using the facilities in this 
%% module i.e the query functions will get a connection from the pool and 
%% return it for you automatically. But you will need it in case you want to 
%% use the underlying driver directly.
%% Once you are done with the connection you will need to return it to the 
%% pool by using return_connection/1.
%% This function is equivalent to get_connection(Pool, Timeout) where 
%% Timeout is 2000 milliseconds (1s).
%% @end
%% -----------------------------------------------------------------------------
-spec get_connection(atom()) -> connection() | {error, timeout}.
get_connection(Pool) ->
    get_connection(Pool, ?GET_CONN_TIMEOUT).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec get_connection(atom(), Timeout :: timeout()) ->
    connection() | {error, timeout}.

get_connection(Pool, Timeout) ->
    get_connection(Pool, Timeout, 1).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
get_connection(PoolName, Timeout, Retries) ->
    case catch episcina:get_connection(PoolName, Timeout) of
        {ok, Pid} ->
            {PoolName, {pgsql_connection, Pid}};
        {error, timeout} ->
            error(timeout);
        {'EXIT', {timeout, _}} when Retries =< ?GET_CONN_RETRIES ->
            ok = try_reconnect(PoolName),
            get_connection(PoolName, Timeout, Retries + 1);
        {'EXIT', {timeout, _}} ->
            error(timeout)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% Returns a connection to the pool. You will only use this in case
%% you have gotten a connection manually by using get_connection/1.
%% @end
%% -----------------------------------------------------------------------------
-spec return_connection(C :: connection()) -> ok.
return_connection({PoolName, {pgsql_connection, Pid}}) ->
    episcina:return_connection(PoolName, Pid).


%% ============================================================================
%% SCHEMA MANAGEMENT
%% ============================================================================


%% -----------------------------------------------------------------------------
%% @doc
%% Returns `true` when the schema with name Name exists, 
%% `false` otherwise.
%% @end
%% -----------------------------------------------------------------------------
-spec has_schema(Name :: binary()) -> boolean().
has_schema(Name) when is_binary(Name) ->
    case lookup_schema(Name) of
        {error, Reason} ->
            error(Reason);
        false ->
            false;
        _ ->
            true
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% Returns the schema with the given Id.
%% @end
%% -----------------------------------------------------------------------------
-spec fetch_schema(Name :: binary()) -> {ok, row()} | error().
fetch_schema(Name) when is_binary(Name) ->
    case lookup_schema(Name) of
        false ->
            error({unknown_schema, Name});
        {error, Reason} ->
            error(Reason);
        Row ->
            Row
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
lookup_schema(Name) when is_binary(Name) ->
    Q = named_query("query_schema.sql", [{id, Name}]),
    case simple_query(Q, [], ?QUERY_TIMEOUT) of
        {ok, []} ->
            false;
        {ok, [R]} ->
            R;
        {ok, Rs} ->
            {error, {multiple_rows, Rs}};
        {error, _} = Error ->
            Error
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% Creates a new schema with all its underlying objects.
%% In pgdb every tenant has its own schema, where the schema name
%% is the Playground Tenant Key.
%% @end
%% -----------------------------------------------------------------------------
-spec create_schema(Name :: binary()) ->
    {ok, row()} | error().
create_schema(Name) when is_binary(Name) ->
    create_schema(Name, <<"">>).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec create_schema(Name :: binary(), Desc :: binary()) ->
    {ok, row()} | error().
create_schema(Name, Desc)
    when is_binary(Name) andalso is_binary(Desc) ->
    Q = named_query("create_schema.sql", [{id, Name}, {desc, Desc}]),
    case simple_query(Q, [{on_error_abort, false}], ?QUERY_TIMEOUT) of
        {ok, _} ->
            {ok, {Name, Desc}};
        {error, _} = Error ->
            Error
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update_schema(Name :: binary(), Desc :: binary()) ->
    {ok, row()} | error().
update_schema(Name, null) ->
    update_schema(Name, <<"null">>);
update_schema(Name, Desc) when is_binary(Name), is_binary(Desc) ->
    % Desc can be 'null'
    Q = [<<"comment on schema ">>, Name, <<" is ">>, $', Desc, $'],
    case simple_query(Q, [], ?QUERY_TIMEOUT) of
        {ok, 1} ->
            {ok, {Name, Desc}};
        {error, _} = Error ->
            Error
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% Drops an existing schema with name Name. This command destroys all the
%% underlying database objects and data.
%% @end
%% -----------------------------------------------------------------------------
-spec drop_schema(ID :: binary()) ->
    ok | error().
drop_schema(ID) when is_binary(ID) ->
    Q = ["drop schema ", ID, " cascade"],
    case simple_query(Q, [], ?QUERY_TIMEOUT) of
        {ok, _} ->
            ok;
        {error, _} = Error ->
            Error
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% Lists all the pgdb schemas.
%% @end
%% -----------------------------------------------------------------------------
list_schemas() ->
    Q = named_query("query_schemas.sql", []),
    simple_query(Q, [], ?QUERY_TIMEOUT).



%% ============================================================================
%% QUERIES
%% ============================================================================


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
simple_query(Q) ->
    simple_query(Q, [], ?QUERY_TIMEOUT).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
simple_query(Q, Opts) ->
    simple_query(Q, Opts, ?QUERY_TIMEOUT).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
simple_query(Q, Opts, Timeout) ->
    C = maybe_get_connection(get_pool_name(Opts)),
    simple_query(Q, Opts, Timeout, C).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
simple_query(Q, Opts, Timeout, C = {_, DBC}) ->
    try
        Res = pgsql_connection:simple_query(Q, Opts, Timeout, DBC),
        process_output(Res, Opts, C)
    after
        maybe_return_connection(C)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
extended_query(Q, Params) ->
    extended_query(Q, Params, [], ?QUERY_TIMEOUT).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
extended_query(Q, Params, Opts) ->
    extended_query(Q, Params, Opts, ?QUERY_TIMEOUT).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
extended_query(Q, Params, Opts, Timeout) ->
    C = maybe_get_connection(get_pool_name(Opts)),
    extended_query(Q, Params, Opts, Timeout, C).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
extended_query(Q, Params, Opts, Timeout, C = {_, DBC}) ->
    try
        Res = pgsql_connection:extended_query(Q, Params, Opts, Timeout, DBC),
        process_output(Res, Opts, C)
    after
        maybe_return_connection(C)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
batch_query(Q, Params) ->
    batch_query(Q, Params, [], ?QUERY_TIMEOUT).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
batch_query(Q, Params, Opts) ->
    batch_query(Q, Params, Opts, ?QUERY_TIMEOUT).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
batch_query(Q, Params, Opts, Timeout) ->
    C = maybe_get_connection(get_pool_name(Opts)),
    batch_query(Q, Params, Opts, Timeout, C).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
batch_query(Q, Params, Opts, Timeout, C = {_, DBC}) ->
    try
        Res = pgsql_connection:batch_query(Q, Params, Opts, Timeout, DBC),
        process_output(Res, Opts, C)
    after
        maybe_return_connection(C)
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec match(
        Table :: list() | binary(), Proj :: list(), Conds :: [condition()]) ->
    {ok, RS :: pgdb_result_set:pgdb_result_set()} | error().
match(Table, Proj, Conditions) ->
    C = maybe_get_connection(get_pool_name([])),
    match(Table, Proj, Conditions, [], C).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec match(
        Table :: list() | binary(), Proj :: list(), Conds :: [condition()],
        Opts :: options()) ->
    {ok, RS :: pgdb_result_set:pgdb_result_set()} |
    error().
match(Table, Proj, Conditions, Opts) ->
    C = maybe_get_connection(get_pool_name(Opts)),
    match(Table, Proj, Conditions, Opts, C).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec match(
        Table :: list() | binary(), Proj :: list(),
        Conds :: [condition()], Opts :: options(),
        C :: connection()) ->
    {ok, RS :: pgdb_result_set:pgdb_result_set()} |
    error().
match(_Table, [], _Conditions, _Opts, _C) ->
    error({invalid_projection, []});

match(Table, Proj, Conditions, Opts0, C)
    when (is_list(Table) andalso Table /= [])
    orelse (is_binary(Table) andalso Table /= <<>>) ->
    Where = case length(Conditions) > 0 of
                true -> <<" where ">>;
                false -> <<>>
            end,
    Q0 = [
        <<"select ">>,
        projections_to_sql(Proj),
        <<" from ">>,
        Table,
        Where
    ],
    {Q1, Params} = conditions_to_sql(Conditions, Q0),
    {Q2, Opts1} = case lists:keytake(lock, 1, Opts0) of
                      false ->
                          {Q1, Opts0};
                      {value, {lock, exclusive}, NewOpts} ->
                          NewQ = lists:append(Q1, [<<" for update">>]),
                          {NewQ, NewOpts};
                      {value, {lock, shared}, NewOpts} ->
                          NewQ = lists:append(Q1, [<<" for share">>]),
                          {NewQ, NewOpts}
                  end,
    extended_query(lists:flatten(Q2), Params, Opts1, ?QUERY_TIMEOUT, C).


%% -----------------------------------------------------------------------------
%% @doc
%% Read a query named Name from pgdb Priv dir and replaces each placehoder
%% in the form of $var with each with property of the same name in Args.
%% @end
%% -----------------------------------------------------------------------------
-spec named_query(string(), [proplists:property()]) -> string() | error().
named_query(Name, Args) ->
    PrivDir = code:priv_dir(pgdb),
    FName = filename:join(PrivDir, Name),
    {ok, File} = file:read_file(FName),
    Q = unicode:characters_to_list(File),
    pgdb_utils:subst(Q, Args).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec transaction(
        Fun :: fun(() -> any())) ->
    any().
transaction(Fun) ->
    transaction(Fun, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec transaction(
        Fun :: fun(() -> any()),
        Opts :: options()) ->
    any().
transaction(Fun, Opts) ->
    % By calling maybe_get_connection we support nesting transaction/2 calls. 
    C = maybe_get_connection(get_pool_name(Opts)),
    transaction(Fun, Opts, C).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec transaction(
        Fun :: fun(() -> any()),
        Opts :: options(),
        C :: connection()) ->
    any() | {error, Reason :: any()}.
transaction(Fun, _Opts, C) ->
    ok = init_tx(C),
    try
        ok = maybe_begin_tx(C),
        % Fun should use this modules query functions, which they will
        % do a rollback in case of an error.
        % If the option on_error_abort was set to true, then any error in 
        % the query functions used within the function block will throw 
        % an exception which we catch below.
        Result = Fun(),
        ok = maybe_commit_tx(C),
        Result
    catch
        throw:Reason ->
            lager:debug("Error  ~p // ~p", [Reason, erlang:get_stacktrace()]),
            % Manual rollback
            _ = maybe_rollback(true, C),
            maybe_throw(is_nested_tx(), Reason)
    after
        ok = maybe_terminate_tx(C),
        ok = maybe_return_connection(C)
    end.



%% ============================================================================
%% PRIVATE
%% ============================================================================


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
init_tx(C) ->
    case get(tx_connection) of
        undefined ->
            % We are initiating a new transaction
            undefined = put(tx_connection, C),
            increment_tx_count();
        C ->
            % This is a nested call, we are joining an existing transaction
            increment_tx_count();
        Other ->
            % We are in a transaction and we are trying to join it
            % using a with a different connection!
            % We return the Other connection to its pool.
            % This should never happen now since we support nesting calls
            % to transaction/2
            ok = return_connection(Other),
            error({existing_connection_in_use, C})
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
increment_tx_count() ->
    case get(tx_count) of
        undefined ->
            undefined = put(tx_count, 1),
            ok;
        N ->
            N = put(tx_count, N + 1),
            ok
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
is_nested_tx() ->
    tx_count() > 1.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
tx_count() ->
    case get(tx_count) of
        undefined -> 0;
        N -> N
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
decrement_tx_count() ->
    case get(tx_count) of
        1 ->
            1 = erase(tx_count),
            ok;
        N ->
            N = put(tx_count, N - 1),
            ok
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
maybe_begin_tx(C) ->
    case is_nested_tx() of
        true ->
            ok;
        false ->
            begin_tx(C)
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
begin_tx({_, DBC} = C) ->
    case pgsql_connection:simple_query(<<"begin;">>, DBC) of
        {'begin', []} ->
            % We do not call process_output because we will create a loop,
            % as process_output will reject explicit transactions when there
            % in already an initiated implicit transaction
            ok;
        Res ->
            % We failed at initiating a tx, we let process_output do its thing,
            % certainly throwing an exception in this case
            _ = process_output(Res, [{on_error_abort, true}], C),
            ok
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
maybe_commit_tx(C) ->
    case is_nested_tx() of
        true ->
            ok;
        false ->
            commit_tx(C)
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
commit_tx({_, DBC} = C) ->
    case pgsql_connection:simple_query(<<"commit;">>, DBC) of
        {commit, []} ->
            % We do not call process_output because we might create a loop
            % in future implementations. At the moment, we do not support
            % nesting explicit transactions
            ok;
        Res ->
            % We failed at committing a tx, we let process_output do its thing,
            % certainly throwing an exception in this case
            _ = process_output(Res, [{on_error_abort, true}], C),
            ok
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
maybe_terminate_tx(C) ->
    ok = decrement_tx_count(),
    case tx_count() == 0 of
        true ->
            terminate_tx(C);
        false ->
            ok
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
terminate_tx(C) ->
    % We remove C from the process dictionary
    C = erase(tx_connection),
    ok.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
maybe_rollback(true, {_, DBC}) ->
    {rollback, []} = pgsql_connection:simple_query("rollback", DBC),
    true;
maybe_rollback(false, _) ->
    false.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
try_reconnect(Pool) ->
    {ok, Pools} = application:get_env(episcina, pools),
    case lists:keyfind(Pool, 1, Pools) of
        {Pool, _} = Conf ->
            case episcina:start_pool(Conf) of
                {ok, _} ->
                    ok;
                {error, Reason} ->
                    error(Reason)
            end;
        false ->
            error({missing_pool_config, Pool})
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
projections_to_sql([P]) ->
    P;
projections_to_sql(Ps) ->
    projections_to_sql(Ps, []).


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
projections_to_sql([], Acc) ->
    lists:reverse(Acc);
projections_to_sql([H | T], []) ->
    projections_to_sql(T, [H]);
projections_to_sql([H | T], Acc) ->
    projections_to_sql(T, [H, "," | Acc]).


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
conditions_to_sql(Cs, Q0) ->
    {Expr, Params, _} = conditions_to_sql('and', Cs, [], 1, []),
    {[Q0, Expr], Params}.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
%% TODO tidy up this function...by using pgdb_utils:join_iolist to generate
%% the conjunction
conditions_to_sql(_Op, [], Q, N, Params) ->
    {Q, lists:flatten(Params), N};

conditions_to_sql(Op, [{is_null, Field} | T], Q0, N, Params) ->
    Q1 = add_expr(Op, [Field, <<" IS NULL">>], Q0),
    conditions_to_sql(Op, T, Q1, N, Params);

conditions_to_sql(Op, [{is_not_null, Field} | T], Q0, N, Params) ->
    Q1 = add_expr(Op, [Field, <<" IS NOT NULL">>], Q0),
    conditions_to_sql(Op, T, Q1, N, Params);

conditions_to_sql(Op, [{'or', L} | T], Q0, N0, Params0) when is_list(L) ->
    {Q1, Params1, N1} = conditions_to_sql('or', L, [], N0, Params0),
    Q2 = add_expr(Op, wrap(Q1), Q0),
    conditions_to_sql(Op, T, Q2, N1, Params1);

conditions_to_sql(Op, [{IOp, Field, Value} | T], Q0, N, Params) ->
    Q1 = add_expr(Op, [Field, atom_to_list(IOp), pgdb_utils:var(N)], Q0),
    conditions_to_sql(Op, T, Q1, N + 1, [Params, Value]).

wrap(L) when is_list(L) ->
    [$(, L, $)].


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
add_expr(_, L, []) ->
    [L];
add_expr('and', L, Q0) ->
    [Q0, <<" AND ">>, L];
add_expr('or', L, Q0) ->
    [Q0, <<" OR ">>, L].


%% -----------------------------------------------------------------------------
%% @private
%% @doc 
%% Prepares the output but also performs a rollback of an existing 
%% transaction if something failed
%% @end
%% -----------------------------------------------------------------------------
-spec process_output(pgsql_connection:result_tuple(), Opts :: options(),
        C :: connection()) ->
    {ok, Count :: non_neg_integer()} |
    {ok, Rows :: pgsql_connection:rows()} |
    {error, any()}.
process_output(L, Opts, C) when is_list(L) ->
    coalesce_output(L, Opts, C);

process_output({error, Reason}, Opts, C) ->
    InTx = is_in_tx(),
    _ = maybe_rollback(InTx, C),
    maybe_throw(InTx, format_reason(Reason), Opts);

process_output({{insert, _TableOID, Count}, []}, _, _) ->
    {ok, Count};

process_output({{delete, Count}, []}, _, _) ->
    {ok, Count};

process_output({{update, Count}, []}, _, _) ->
    {ok, Count};

process_output({{move, Count}, []}, _, _) ->
    {ok, Count};

process_output({{fetch, Count}, []}, _, _) ->
    {ok, Count};

process_output({{copy, Count}, []}, _, _) ->
    {ok, Count};

process_output({{insert, _TableOID, _Count}, Rows}, _, _) ->
    {ok, Rows};

process_output({{delete, Count}, _Rows}, _, _) ->
    {ok, Count};

process_output({{update, _Count}, Rows}, _, _) ->
    {ok, Rows};

process_output({{select, _Count}, Rows}, _, _) ->
    {ok, Rows};

process_output({{create, _What}, []}, _, _) ->
    {ok, 1};

process_output({comment, []}, _, _) ->
    {ok, 1};

process_output({{drop, _What}, []}, _, _) ->
    {ok, 1};

process_output({{alter, _What}, []}, _, _) ->
    {ok, 1};

process_output({'begin', []}, Opts, C) ->
    % This is the result of a user explicitly sending the "begin;" sql command
    % We call "begin;" out of band in begin_tx/1 so we shouldn't loop here.
    % If we are already in a tx we need to rollback 
    % (the block already processed) and abort.
    case is_in_tx() of
        true ->
            _ = maybe_rollback(true, C),
            Reason = {existing_transaction_in_progress, <<"Nested transactions not supported. Explicit transaction cannot join existing transactions.">>},
            maybe_throw(true, format_reason(Reason), Opts);
        false ->
            {ok, 0}
    end;

process_output({commit, []}, Opts, C) ->
    % Cleanup
    case is_in_tx() of
        true ->
            % This could be horrible. 
            % The user sent an explicit commit in the middle of an implicit 
            % transaction.
            % We are not sure anything is wrong but when it dos, we won't be 
            % able to rollback the changes because the user partially 
            % committed them.
            % For now we do not do anything smart and fail
            Desc = "Explicit transaction termination within implict transaction may have caused and inconsistent database state.",
            Reason = {inconsistent_state, Desc},
            lager:warning(Desc),
            _ = maybe_rollback(true, C),
            maybe_throw(true, format_reason(Reason), Opts);
        false ->
            {ok, 0}
    end;

process_output({rollback, []}, Opts, _C) ->
    % This is considered an error since not only the rollback command itself 
    % might return {rollback, []} e.g. commit will return this when a rollback
    % was performed before it
    maybe_throw(is_in_tx(), rollback, Opts);

process_output({set, []}, _, _) ->
    {ok, 0};

process_output({listen, []}, _, _) ->
    {ok, 0};

process_output({notify, []}, _, _) ->
    {ok, 0};

process_output({'do', []}, _, _) ->
    {ok, 0};

process_output({Other, []}, Opts, _) ->
    maybe_throw(is_in_tx(), {unknown_command, Other}, Opts).


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
coalesce_output(L, Opts, C) ->
    coalesce_output(L, [], [], 0, is_in_tx(), Opts, C).


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
coalesce_output([], [], [], Cnt, _, _, _) ->
    {ok, Cnt};

coalesce_output([], [], Rows, _, _, _, _) ->
    {ok, lists:append(Rows)};

coalesce_output([], [R], _, _, InTx, Opts, C) ->
    % We have one error
    _ = maybe_rollback(InTx, C),
    maybe_throw(InTx, R, Opts);

coalesce_output([], Rs, _, _, InTx, Opts, C) ->
    % We have multiple errors
    _ = maybe_rollback(InTx, C),
    maybe_throw(InTx, {multiple, Rs}, Opts);

coalesce_output([{error, R} | T], Rs, Rows, Cnt, InTx, Opts, C) ->
    coalesce_output(T, [format_reason(R) | Rs], Rows, Cnt, InTx, Opts, C);

coalesce_output([{'begin', []} | T], Rs, Rows, Cnt, _, Opts, C) ->
    coalesce_output(T, Rs, Rows, Cnt, true, Opts, C);

coalesce_output([H | T], Rs, Rows, Cnt, InTx, Opts, C) ->
    case process_output(H, Opts, C) of
        {ok, N} when is_integer(N) ->
            coalesce_output(T, Rs, Rows, Cnt + N, InTx, Opts, C);
        {ok, L} when is_list(L) ->
            coalesce_output(T, Rs, [L | Rows], Cnt, InTx, Opts, C);
        {error, R} ->
            coalesce_output(
                T, [format_reason(R) | Rs], Rows, Cnt, InTx, Opts, C)
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
maybe_throw(true, Reason) ->
    throw(Reason);
maybe_throw(false, Reason) ->
    {error, Reason}.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
maybe_throw(false, Reason, _Opts) ->
    maybe_throw(false, Reason);

maybe_throw(true, Reason, Opts) ->
    case lists:keyfind(on_error_abort, 1, Opts) of
        {on_error_abort, Val} ->
            maybe_throw(Val, Reason);
        false ->
            maybe_throw(?DEFAULT_ON_ERROR_ABORT, Reason);
        Other ->
            throw({invalid_option, Other})
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
format_reason({pgsql_error, L}) ->
    {pgdb_pg_error:name(error_code(L)), error_message(L)};
format_reason(Reason) ->
    Reason.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
error_code(L) ->
    case lists:keyfind(code, 1, L) of
        {code, Code} ->
            Code;
        false ->
            undefined
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
error_message(L) ->
    case lists:keyfind(message, 1, L) of
        {message, Code} ->
            Code;
        false ->
            undefined
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
get_pool_name(Opts) ->
    case lists:keyfind(pool, 1, Opts) of
        {pool, Name} ->
            Name;
        false ->
            % We default to the first pool
            {ok, [{Name, _} | _T]} = application:get_env(episcina, pools),
            Name
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% Tries to get a connection from the process dictionary and if it fails
%% calls get_connection/1.  
%% transaction/2 uses the process dictionary to cache the current connection.
%% @end
%% -----------------------------------------------------------------------------
maybe_get_connection(Pool) ->
    case get(tx_connection) of
        undefined ->
            get_connection(Pool);
        Conn ->
            Conn
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
maybe_return_connection(C) ->
    case get(tx_connection) of
        C ->
            % We are in a tx so we keep it.
            % transaction/2 will explicitly return it when finish
            ok;
        _Other ->
            % We are not in a tx or this is not the tx connection, 
            % return it
            return_connection(C)
    end.


%% -----------------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% -----------------------------------------------------------------------------
is_in_tx() ->
    get(tx_connection) =/= undefined.



