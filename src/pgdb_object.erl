%% =============================================================================
%%
%% pgdb_object.erl
%%
%% Copyright (c) 2016 - 2019 Ngineo Limited t/a Leapsight. All Rights Reserved.
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

%% @doc This module defines the pgdb_object() behaviour. The behaviour is mainly
%% used to ensure a common interface to all the domain objects.
%% It also provides functions to perform all the operations generically.
%% These functions operate under the following assumptions
%% - Every entity maps to one db table
%% - There is only one primary key column
%% - Read-only (immutable) columns need to have a default value in the db,
%%   pgdb_object will not include this columns in the INSERT or UPDATE
%%   operations.
%% - The primary_key is not read-only as we allow to set its value during
%%   INSERT, but is not included in the UDPATE i.e. is immutable once set
%% @end
-module(pgdb_object).

-define(SCHEMA_TABLE(S, T), <<S/binary, $., T/binary>>).


-export([add/3]).
-export([collect_values/3]).
-export([fetch/4]).
-export([from_map/2]).
-export([get_value/3]).
-export([id/2]).
-export([list/3]).
-export([lookup/4]).
-export([match/4]).
-export([member/3]).
-export([new/1]).
-export([remove/3]).
-export([set_value/4]).
-export([to_map/2]).
-export([update/3]).


%% ============================================================================
%% UTILS IMPLEMENTATION
%% ============================================================================

-spec new(Spec :: pb_object_spec:object_spec()) -> pgdb:row().
new(Spec) ->
    Cols = pgdb_object_spec:column_names(Spec),
    L = [pgdb_object_spec:eval_column_default(Spec, C) || C <- Cols],
    list_to_tuple(L).


-spec id(Spec :: pb_object_spec:object_spec(), Row :: pgdb:row()) -> binary().
id(Spec, Row) ->
    get_value(Spec, pgdb_object_spec:primary_key(Spec), Row).


-spec from_map(Spec :: pb_object_spec:object_spec(), Map :: map()) -> pgdb:row().
from_map(Spec, Map) ->
    Cols = pgdb_object_spec:column_names(Spec),
    L = [
        begin
            Type = pgdb_object_spec:column_type(Spec, C),
            Val = maps:get(
                C, Map, pgdb_object_spec:eval_column_default(Spec, C)),
            coerse_type(Type, Val)
        end || C <- Cols
    ],
    list_to_tuple(L).


-spec to_map(Spec :: pb_object_spec:object_spec(), Row :: pgdb:row()) -> map().
to_map(Spec, Row) ->
    Cols = pgdb_object_spec:column_names(Spec),
    L = [{C, element(pgdb_object_spec:column_index(Spec, C), Row)}
        || C <- Cols],
    maps:from_list(L).


-spec add(Schema :: binary(), Spec :: pb_object_spec:object_spec(), Row :: pgdb:row()) ->
    {ok, NewRow :: pgdb:row()} | pgdb:error().
add(Schema, Spec, Row) ->
    Map = to_map(Spec, Row),
    AllCols = pgdb_object_spec:column_names(Spec),
    {Cols, Params} = collect_cols_and_vals(Map, AllCols),
    Table = pgdb_object_spec:table_name(Spec),
    ColStr = pgdb_utils:join_iolist(Cols, ", "),
    Vars = ["$" ++ integer_to_list(X) || X <- lists:seq(1, length(Cols))],
    VarStr = pgdb_utils:join_iolist(Vars, ", "),
    RetCols = pgdb_utils:join_iolist(AllCols, ", "),

    Q = lists:flatten([
        <<"insert into ">>, ?SCHEMA_TABLE(Schema, Table), $\s,
        $(, ColStr, $), <<" values ">>, $(, VarStr, $),
        <<" returning ">>, RetCols
    ]),
    case pgdb:extended_query(Q, Params) of
        {ok, [NewRow]} -> {ok, NewRow};
        {error, _} = Error ->
            Error
    end.


-spec update(Schema :: binary(), Spec :: pb_object_spec:object_spec(), Row :: pgdb:row()) ->
    {ok, NewRow :: pgdb:row()} | pgdb:error().
update(Schema, Spec, Row) ->
    Table = pgdb_object_spec:table_name(Spec),
    PK = pgdb_object_spec:primary_key(Spec),
    MCols = lists:subtract(pgdb_object_spec:mutable_column_names(Spec), [PK]),
    % We shift indexes by 1 so that id is $1
    Pairs = lists:zip(MCols, lists:seq(2, length(MCols) + 1)),
    Bindings = pgdb_utils:join_iolist(
        [begin
             Var = integer_to_binary(I),
             <<Col/binary, " = ", $$, Var/binary>>
         end || {Col, I} <- Pairs], ", "),
    All = pgdb_utils:join_iolist(pgdb_object_spec:column_names(Spec), ", "),
    Params = [id(Spec, Row) | collect_values(Spec, MCols, Row)],

    Q = [
        <<"update ">>, ?SCHEMA_TABLE(Schema, Table),
        <<" set ">>, Bindings,
        <<" where ", PK/binary, " = $1">>,
        <<" returning ">>, All
    ],
    case pgdb:extended_query(Q, Params) of
        {ok, [NewRow]} -> {ok, NewRow};
        {error, _} = Error -> Error
    end.


-spec remove(Schema :: binary(), Spec :: pb_object_spec:object_spec(), Row :: pgdb:row()) ->
    ok | pgdb:error().
remove(Schema, Spec, Row) ->
    Table = pgdb_object_spec:table_name(Spec),
    Params = [id(Spec, Row)],
    Q = [
        <<"delete from ">>, ?SCHEMA_TABLE(Schema, Table),
        <<" where id = $1">>
    ],
    case pgdb:extended_query(Q, Params) of
        {ok, 1} ->
            ok;
        {error, _} = Error ->
            Error
    end.


-spec member(Schema :: binary(), Spec :: pb_object_spec:object_spec(), Row :: pgdb:row()) ->
    boolean() | pgdb:error().
member(Schema, Spec, Row) ->
    case lookup(Schema, Spec, id(Spec, Row), []) of
        {error, Reason} ->
            throw(Reason);
        false ->
            false;
        _Other ->
            true
    end.


-spec fetch(Schema :: binary(), Spec :: pb_object_spec:object_spec(), UUID :: binary(),
        Opts :: [proplists:property()]) ->
    pgdb:row() | pgdb:error().
fetch(Schema, Spec, UUID, Opts) ->
    case lookup(Schema, Spec, UUID, Opts) of
        false ->
            error({not_found, UUID});
        Other ->
            Other
    end.


-spec lookup(
        Schema :: binary(), Spec :: pb_object_spec:object_spec(), UUID :: binary(),
        Opts :: [proplists:property()]) ->
    pgdb:row() | false | pgdb:error().
lookup(Schema, Spec, UUID, Opts) ->
    Table = pgdb_object_spec:table_name(Spec),
    Cols = pgdb_object_spec:column_names(Spec),
    PK = pgdb_object_spec:primary_key(Spec),
    Conds = append_conditions([{'=', PK, UUID}], Spec),
    Res = pgdb:match(
        ?SCHEMA_TABLE(Schema, Table), Cols, Conds, Opts),
    case Res of
        {ok, []} ->
            false;
        {ok, [Obj]} ->
            Obj;
        {ok, L} ->
            {error, {multiple_rows, L}};
        {error, _} = Error ->
            Error
    end.


-spec list(
        Schema :: binary(), Spec :: pb_object_spec:object_spec(), Opts :: [proplists:property()]) ->
    {ok, RS :: pgdb_result_set:result_set()} | pgdb:error().
list(Schema, Spec, Opts) ->
    match(Schema, Spec, [], Opts).


-spec match(
        Schema :: binary(), Spec :: pb_object_spec:object_spec(),
        Conds :: [pgdb:condition()], Opts :: [proplists:property()]) ->
    {ok, RS :: pgdb_result_set:result_set()} |
    pgdb:error().
match(Schema, Spec, Conditions, Opts) ->
    Table = pgdb_object_spec:table_name(Spec),
    Cols = pgdb_object_spec:column_names(Spec),
    Conds = append_conditions(Conditions, Spec),
    Res = pgdb:match(?SCHEMA_TABLE(Schema, Table), Cols, Conds, Opts),
    maybe_result_set(Cols, Res).



collect_values(Spec, Ks, Row) ->
    [get_value(Spec, K, Row) || K <- Ks].


get_value(Spec, Key, Row) ->
    N = pgdb_object_spec:column_index(Spec, Key),
    element(N, Row).


set_value(Spec, Key, Value, Row) ->
    N = pgdb_object_spec:column_index(Spec, Key),
    setelement(N, Row, Value).


%% @private
%% @doc we need this as pgsql does not return the projection head!
%% Without it we can't create a pgdb_result_set
maybe_result_set(_Head, {error, _} = Error) -> Error;
maybe_result_set(Head, {ok, Rows}) -> {ok, pgdb_result_set:new(Head, Rows)}.


%% @private
coerse_type(timestamp, Value) when is_binary(Value) ->
    qdate:to_date(Value);
coerse_type(L, Value) when is_list(L) ->
    case lists:member(Value, L) of
        true -> Value;
        false -> error({bad_type, Value})
    end;
coerse_type(_, Value) ->
    %% We let the db do the type check
    Value.

%% @private
append_conditions(L1, Spec) ->
    case pgdb_object_spec:qualifier(Spec) of
        undefined ->
            L1;
        L2 when is_list(L2) ->
            lists:append(L1, L2);
        Term ->
            [Term | L1]
    end.


%% @private
collect_cols_and_vals(Map, AllCols) ->
    collect_cols_and_vals(Map, AllCols, [], []).


%% @private
collect_cols_and_vals(_, [], Cols0, Vals0) ->
    {lists:reverse(Cols0), lists:reverse(Vals0)};

collect_cols_and_vals(Map, [H | T], Cols0, Vals0) ->
    case maps:get(H, Map, null) of
        null ->
            collect_cols_and_vals(Map, T, Cols0, Vals0);
        V ->
            Cols1 = [H | Cols0],
            Vals1 = [V | Vals0],
            collect_cols_and_vals(Map, T, Cols1, Vals1)
    end.

