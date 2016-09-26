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

-type key()         ::  binary().
-type value()       ::  binary().
-type object()      ::  {key(), value()}.

-export_type([key/0]).
-export_type([value/0]).
-export_type([object/0]).

-export([add/4]).
-export([fetch/3]).
-export([fetch/4]).
-export([list/2]).
-export([lookup/3]).
-export([lookup/4]).
-export([match/3]).
-export([match/4]).
-export([remove/3]).
% -export([update/4]).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add(binary(), binary(), key(), value()) -> {ok, object()} | pgdb:error().

add(Schema, Table, Key, Value) when is_binary(Schema), is_binary(Table), is_binary(Key), is_binary(Value) ->
    Q = [
        <<"insert into ">>, ?SCHEMA_TABLE(Schema, Table), 
        <<"(key, value) values ($1, ($2::text)::jsonb);">>
    ],
    case pgdb:extended_query(Q, [Key, Value]) of
       {ok, _} -> 
           {Key, Value};
       {error, _} = Error ->
           Error
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec fetch(
    Schema :: binary(), 
    Table :: binary(), 
    Key :: key()) -> object() | pgdb:error().
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
    Opts :: [proplists:property()]) -> object() | pgdb:error().
fetch(Schema, Table, Key, Opts) ->
    case lookup(Schema, Table, Key, Opts) of
        false ->
            error({not_found, Key});
        Other ->
            Other
    end.



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec lookup(binary(), binary(), binary()) -> object().

lookup(Schema, Table, Key) ->
    lookup(Schema, Table, Key, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec lookup(binary(), binary(), key(), [proplists:property()]) -> object().

lookup(Schema, Table, Key, Opts) ->
    Q = [
        <<"select key, (value::text)::jsonb from ">>, ?SCHEMA_TABLE(Schema, Table),
        <<" where key = ">>, $', Key, $'
    ],
    case pgdb:simple_query(Q, Opts) of
        {ok, []} ->
            false;
        {ok, [Row]} ->
            maybe_format_rows([Row]);
        {ok, L} ->
            {error, {multiple_rows, L}};
        {error, _} = Error ->
            Error
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec list(binary(), binary()) -> [object()].

list(Schema, Table) ->
    match(Schema, Table, <<>>).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec match(binary(), binary(), binary()) -> [object()] | pgdb:error().

match(Schema, Table, Pattern) ->
    match(Schema, Table, Pattern, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec match(binary(), binary(), binary(), list()) -> [object()] | pgdb:error().

match(Schema, Table, Pattern, Opts0) 
when is_binary(Schema), is_binary(Table), is_binary(Pattern), is_list(Opts0) ->
    Where = case Pattern of
        <<"{}">> ->
            $;;
        <<>> ->
            $;;
        _ ->
            <<" where value @> ", $', Pattern/binary, $', $;>>
    end,
    Q = [
        <<"select key, (value::text)::jsonb from ">>, ?SCHEMA_TABLE(Schema, Table),
        Where
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
    maybe_format_rows(pgdb:simple_query(lists:flatten(Q1), Opts1)).


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



maybe_format_rows({error, _} = Error) ->
    Error;

maybe_format_rows({ok, Rows}) ->
    maybe_format_rows(Rows);

maybe_format_rows(Rows) ->
    [{Key, Value} || {Key, {jsonb, Value}} <- Rows].