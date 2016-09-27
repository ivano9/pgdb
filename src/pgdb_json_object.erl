%% =============================================================================
%%
%% pgdb_json_object.erl
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


-module(pgdb_json_object).

-define(KEY, <<"key">>).
-define(VALUE, <<"value">>).
-define(SCHEMA_TABLE(S, T), <<S/binary, $., T/binary>>).

-type key()             ::  binary().
-type value()           ::  binary() | map() | proplist:proplist().

-export_type([key/0]).
-export_type([value/0]).

-export([add/4]).
-export([fetch/3]).
-export([fetch/4]).
-export([list/2]).
-export([list/3]).
-export([lookup/3]).
-export([lookup/4]).
-export([match/3]).
-export([match/4]).
-export([remove/3]).
-export([update/4]).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add(binary(), binary(), key(), value() | any()) -> ok | pgdb:error().

add(Schema, Table, Key, Value) 
when is_binary(Schema), is_binary(Table), is_binary(Key), is_binary(Value) ->
    Q = [
        <<"insert into ">>, ?SCHEMA_TABLE(Schema, Table), 
        <<"(key, value) values ($1, ($2::text)::jsonb);">>
    ],
    case pgdb:extended_query(Q, [Key, Value]) of
       {ok, _} -> 
           ok;
       {error, _} = Error ->
           Error
    end;

add(Schema, Table, Key, Value) 
when is_binary(Schema), is_binary(Table), is_binary(Key) ->
    add(Schema, Table, Key, jsx:encode(Value)).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update(binary(), binary(), key(), any()) -> ok | pgdb:error().
update(Schema, Table, Key, Value)
when is_binary(Schema), is_binary(Table), is_binary(Key), is_binary(Value) ->
    Q = [
        <<"update ">>, ?SCHEMA_TABLE(Schema, Table), 
        <<" set value = ($2::text)::jsonb where key = $1;">>],
    case pgdb:extended_query(Q, [Key, Value]) of
       {ok, _} -> 
           ok;
       {error, _} = Error ->
           Error
    end;

update(Schema, Table, Key, Value)
when is_binary(Schema), is_binary(Table), is_binary(Key) ->
    update(Schema, Table, Key, jsx:encode(Value)).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec fetch(
    Schema :: binary(), 
    Table :: binary(), 
    Key :: key()) -> value() | no_return().
fetch(Schema, Table, Key) ->
    fetch(Schema, Table, Key, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec fetch(
    Schema :: binary(), 
    Table :: binary(), 
    Key :: key(),
    Opts :: [proplists:property()]) -> value() | no_return().
fetch(Schema, Table, Key, Opts) ->
    case lookup(Schema, Table, Key, Opts) of
        false ->
            error({not_found, Key});
        {error, Reason} ->
            error(Reason);
        Value ->
            Value
    end.



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec lookup(binary(), binary(), binary()) -> value() | false | pgdb:error().

lookup(Schema, Table, Key) ->
    lookup(Schema, Table, Key, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec lookup(binary(), binary(), key(), [proplists:property()]) -> 
    value() | false | pgdb:error().

lookup(Schema, Table, Key, Opts) ->
    Q = [
        <<"select key, (value::text)::jsonb from ">>, ?SCHEMA_TABLE(Schema, Table),
        <<" where key = ">>, $', Key, $'
    ],
    case pgdb:simple_query(Q, Opts) of
        {ok, []} ->
            false;
        {ok, [{_, {jsonb, Value}}]} ->
            maybe_decode(decode_json(Opts), Value);
        {ok, L} ->
            {error, {multiple_rows, L}};
        {error, _} = Error ->
            Error
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec list(binary(), binary()) -> 
    [map() | proplists:proplists()] | iolist() | pgdb:error().

list(Schema, Table) ->
    list(Schema, Table, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec list(binary(), binary(), list()) ->
    [map() | proplists:proplists()] | iolist() | pgdb:error().

list(Schema, Table, Opts) ->
    match(Schema, Table, <<>>, Opts).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec match(binary(), binary(), binary()) ->
    [map() | proplists:proplists()] | iolist() | pgdb:error().

match(Schema, Table, Pattern) ->
    match(Schema, Table, Pattern, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec match(binary(), binary(), binary(), list()) ->
    [map() | proplists:proplists()] | iolist() | pgdb:error().

match(Schema, Table, Patterns, Opts0) 
when is_binary(Schema), is_binary(Table), is_list(Patterns), is_list(Opts0) ->
    Q = [
        <<"select key, (value::text)::jsonb from ">>, 
        ?SCHEMA_TABLE(Schema, Table) | match_where_clause(Patterns)
    ],
    {Q1, Opts1} = case lists:keytake(lock, 1, Opts0) of
        false ->
            {Q, Opts0};
        {value, {lock, exclusive}, NewOpts} ->
            NewQ = lists:append(Q, [<<" for update">>]),
            {NewQ, NewOpts};
        {value, {lock, shared}, NewOpts} ->
            NewQ = lists:append(Q, [<<" for share">>]),
            {NewQ, NewOpts}
    end,
    maybe_unwrap(pgdb:simple_query(lists:flatten(Q1), Opts1), Opts1);

match(Schema, Table, Pattern, Opts) 
when is_binary(Schema), is_binary(Table), is_list(Opts) ->
    match(Schema, Table, [Pattern], Opts).


%% @private
match_where_clause(Patterns) ->
    match_where_clause(Patterns, []).

%% @private
match_where_clause([<<>>|T], Acc) ->
    match_where_clause(T, Acc);

match_where_clause([<<"{}">>|T], Acc) ->
    match_where_clause(T, Acc);

match_where_clause([Bin|T], Acc) when is_binary(Bin) ->
    Clause = <<" value @> ", $', Bin/binary, $'>>,
    match_where_clause(T, [Clause|Acc]);

match_where_clause([Pat|T], Acc) ->
    Bin = jsx:encode(Pat),
    Clause = <<" value @> ", $', Bin/binary, $'>>,
    match_where_clause(T, [Clause|Acc]);

match_where_clause([], []) ->
    [<<>>];

match_where_clause([], L) ->
    Clauses = pgdb_utils:join_iolist(L, <<" OR">>),
    [<<" where ">> | Clauses].



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec remove(binary(), binary(), binary()) -> ok | pgdb:error().

remove(Schema, Table, Key) ->
    Q = [<<"delete from ">>, ?SCHEMA_TABLE(Schema, Table), <<" where key = $1">>],
    case pgdb:extended_query(Q, [Key]) of
        {ok, 1} ->
            ok;
        {error, _} = Error ->
            Error
    end.





%% =============================================================================
%% PRIVATE
%% =============================================================================


%% @private
maybe_unwrap({error, _} = Error, _) ->
    Error;

maybe_unwrap({ok, Rows}, Opts) ->
    Decode = decode_json(Opts),
    L = [maybe_decode(Decode, Value) || {_, {jsonb, Value}} <- Rows],
    case Decode of 
        {true, _} ->
            pgdb_utils:to_json_iolist(L);
        false ->
            L
    end.


%% @private
maybe_decode(false, Bin) ->
    Bin;
maybe_decode({true, Opts}, Bin) ->
    jsx:decode(Bin, Opts).

    


%% @private
decode_json(Opts) ->
    case lists:keyfind(decode_json, 1, Opts) of
        {decode_json, false} ->
            false;
        {decode_json, true} ->
            {true, [return_maps, {labels, existing_atom}]};
        {decode_json, PList} ->
            {true, PList};
        false ->
            {true, [return_maps, {labels, existing_atom}]}
    end.