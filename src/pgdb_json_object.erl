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
-export([add/5]).
-export([fetch/3]).
-export([fetch/4]).
-export([list/2]).
-export([list/3]).
-export([lookup/3]).
-export([lookup/4]).
-export([match/3]).
-export([match/4]).
-export([remove/3]).
-export([remove/4]).
-export([update/4]).
-export([update/5]).
-export([is_member/3]).
-export([is_member/4]).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add(binary(), binary(), key(), value() | any()) -> ok | no_return().

add(Schema, Table, Key, Value)
when is_binary(Schema), is_binary(Table), is_binary(Key), is_binary(Value) ->
    Q = [
        <<"insert into ">>, ?SCHEMA_TABLE(Schema, Table),
        <<"(key, value) values ($1, ($2::text)::jsonb);">>
    ],
    case pgdb:extended_query(Q, [Key, Value]) of
       {ok, _} ->
           ok;
       {error, Reason} ->
           error(Reason)
    end;

add(Schema, Table, Key, Value)
when is_binary(Schema), is_binary(Table), is_binary(Key) ->
    add(Schema, Table, Key, jsx:encode(Value)).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec add(binary(), binary(), key(), value() | any(), list()) -> 
    ok | no_return().

add(Schema, Table, Key, Value, Opts)
when is_binary(Schema), is_binary(Table), is_binary(Key), is_binary(Value) ->
    Q = [
        <<"insert into ">>, ?SCHEMA_TABLE(Schema, Table),
        <<"(key, value) values ($1, ($2::text)::jsonb);">>
    ],
    case pgdb:extended_query(Q, [Key, Value], Opts) of
       {ok, _} ->
           ok;
       {error, Reason} ->
           error(Reason)
    end;

add(Schema, Table, Key, Value, Opts)
when is_binary(Schema), is_binary(Table), is_binary(Key) ->
    add(Schema, Table, Key, jsx:encode(Value), Opts).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update(binary(), binary(), key(), any()) -> ok | no_return().
update(Schema, Table, Key, Value)
when is_binary(Schema), is_binary(Table), is_binary(Key), is_binary(Value) ->
    Q = [
        <<"update ">>, ?SCHEMA_TABLE(Schema, Table),
        <<" set value = ($2::text)::jsonb where key = $1;">>],
    case pgdb:extended_query(Q, [Key, Value]) of
       {ok, _} ->
           ok;
       {error, Reason} ->
           error(Reason)
    end;

update(Schema, Table, Key, Value)
when is_binary(Schema), is_binary(Table), is_binary(Key) ->
    update(Schema, Table, Key, jsx:encode(Value)).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec update(binary(), binary(), key(), any(), list()) -> ok | no_return().
update(Schema, Table, Key, Value, Opts)
when is_binary(Schema), is_binary(Table), is_binary(Key), is_binary(Value) ->
    Q = [
        <<"update ">>, ?SCHEMA_TABLE(Schema, Table),
        <<" set value = ($2::text)::jsonb where key = $1;">>],
    case pgdb:extended_query(Q, [Key, Value], Opts) of
       {ok, _} ->
           ok;
       {error, Reason} ->
           error(Reason)
    end;

update(Schema, Table, Key, Value, Opts)
when is_binary(Schema), is_binary(Table), is_binary(Key) ->
    update(Schema, Table, Key, jsx:encode(Value), Opts).



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
-spec lookup(binary(), binary(), binary()) -> value() | false | no_return().

lookup(Schema, Table, Key) ->
    lookup(Schema, Table, Key, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec lookup(binary(), binary(), key(), [proplists:property()]) ->
    value() | false | no_return().

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
            error({multiple_rows, L});
        {error, Reason} ->
            error(Reason)
    end.



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec is_member(binary(), binary(), key()) -> boolean().

is_member(Schema, Table, Key) ->
    Q = [
        <<"select exists(select 1 from ">>, ?SCHEMA_TABLE(Schema, Table),
        <<" where key = $1);">>
    ],
    case pgdb:extended_query(Q, [Key]) of
        {ok, [{Res}]} ->
            Res;
        _ ->
            false
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec is_member(binary(), binary(), key(), list()) -> boolean().

is_member(Schema, Table, Key, Opts) ->
    Q = [
        <<"select exists(select 1 from ">>, ?SCHEMA_TABLE(Schema, Table),
        <<" where key = $1);">>
    ],
    case pgdb:extended_query(Q, [Key], Opts) of
        {ok, [{Res}]} ->
            Res;
        _ ->
            false
    end.


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec list(binary(), binary()) ->
    [map() | proplists:proplists()] | iolist() | no_return().

list(Schema, Table) ->
    list(Schema, Table, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec list(binary(), binary(), list()) ->
    [map() | proplists:proplists()] | iolist() | no_return().

list(Schema, Table, Opts) ->
    match(Schema, Table, <<>>, Opts).



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec match(binary(), binary(), binary()) ->
    [map() | proplists:proplists()] | iolist() | no_return().

match(Schema, Table, Pattern) ->
    match(Schema, Table, Pattern, []).


%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec match(binary(), binary(), binary(), list()) ->
    [map() | proplists:proplists()] | iolist() | no_return().

match(Schema, Table, Patterns, Opts0)
when is_binary(Schema), is_binary(Table), is_list(Patterns), is_list(Opts0) ->
    {SortBy, Opts1} = case lists:keytake(order_by, 1, Opts0) of
        false ->
            {[], Opts0};
        {value, {order_by, L}, NewOpts0} when is_list(L)->
            {L, NewOpts0}
    end,
    Q = match_query(
        lists:keyfind(select, 1, Opts1), Schema, Table, Patterns, SortBy),
    
    {Q1, Opts2} = case lists:keytake(lock, 1, Opts1) of
        false ->
            {Q, Opts1};
        {value, {lock, exclusive}, NewOpts} ->
            NewQ = lists:append(Q, [<<" for update">>]),
            {NewQ, NewOpts};
        {value, {lock, shared}, NewOpts} ->
            NewQ = lists:append(Q, [<<" for share">>]),
            {NewQ, NewOpts}
    end,
    unwrap(pgdb:simple_query(lists:flatten(Q1), Opts2), Opts2);

match(Schema, Table, Pattern, Opts)
when is_binary(Schema), is_binary(Table), is_list(Opts) ->
    match(Schema, Table, [Pattern], Opts).


%% @private
match_query(false, Schema, Table, Patterns, SortBy) ->
    [
        <<"select (value::text)::jsonb from ">>,
        ?SCHEMA_TABLE(Schema, Table) | 
        lists:append(
            match_where_clauses(Patterns),
            match_sort_by_clause(SortBy))
    ];

match_query({select, Fields}, Schema, Table, Patterns, SortBy) ->
% select row_to_json(r) :: jsonb from (select value :: jsonb ->>'id' as id from shipments.batch) as r
    L = [attr_to_sql(F)|| F <- Fields],
    Proj = pgdb_utils:join_iolist(L, <<", ">>),
    [
        <<"select row_to_json(row) :: jsonb from (select ">>,
        Proj,
        <<" from ">>,
        ?SCHEMA_TABLE(Schema, Table) |
        lists:append([
            match_where_clauses(Patterns), 
            match_sort_by_clause(SortBy), 
            [<<") as row;">>]
        ])
    ].


%% @private
attr_to_sql(Attr) when is_bitstring(Attr) ->
    <<"value :: jsonb ->> ", $', Attr/binary, $'," as ", Attr/binary>>;

attr_to_sql(Attr) when is_atom(Attr) ->
    attr_to_sql(list_to_bitstring(atom_to_list(Attr)));

attr_to_sql({Attr, Type}) when is_bitstring(Attr), is_bitstring(Type) ->
    attr_to_sql(Attr, Type);

attr_to_sql({Attr, Type}) when is_atom(Attr) ->
    attr_to_sql({list_to_bitstring(atom_to_list(Attr)), Type});

attr_to_sql({Attr, Type}) when is_atom(Type) ->
    attr_to_sql({Attr, list_to_bitstring(atom_to_list(Type))}).




attr_to_sql(Attr, Type) ->
    <<
        "(value :: jsonb ->> ", $', Attr/binary, $', ")::", Type/binary,
        " as ", Attr/binary
    >>.


%% @private
match_where_clauses(Patterns) ->
    match_where_clauses(Patterns, []).

%% @private
% match_where_clauses([{'and', Ps}|T], Acc) when is_list(Ps) ->   
%     Conj = pgdb_utils:join_iolist([match_where_clause(P) || P <- Ps], <<" AND">>),
%     match_where_clauses(T, [Conj|Acc]);

match_where_clauses([{'not', <<>>} | T], Acc) ->
    match_where_clauses(T, Acc);

match_where_clauses([{'not', <<"{}">>}|T], Acc) ->
    match_where_clauses(T, Acc);

match_where_clauses([{'not', Json}|T], Acc) when is_binary(Json) ->
    Clause = <<" not value @> ", $', Json/binary, $'>>,
    match_where_clauses(T, [Clause|Acc]);

match_where_clauses([{'not', Pat}|T], Acc) ->
    Json = jsx:encode(Pat),
    Clause = <<" not value @> ", $', Json/binary, $'>>,
    match_where_clauses(T, [Clause|Acc]);

match_where_clauses([<<>>|T], Acc) ->
    match_where_clauses(T, Acc);

match_where_clauses([<<"{}">>|T], Acc) ->
    match_where_clauses(T, Acc);

match_where_clauses([Json|T], Acc) when is_binary(Json) ->
    Clause = <<" value @> ", $', Json/binary, $'>>,
    match_where_clauses(T, [Clause|Acc]);

match_where_clauses([Pat|T], Acc) ->
    Json = jsx:encode(Pat),
    Clause = <<" value @> ", $', Json/binary, $'>>,
    match_where_clauses(T, [Clause|Acc]);

match_where_clauses([], []) ->
    [<<>>];

match_where_clauses([], L) ->
    Clauses = pgdb_utils:join_iolist(L, <<" OR">>),
    [<<" WHERE ">> | Clauses].


%% @private
match_sort_by_clause([]) ->
    [];

match_sort_by_clause(Fields) ->
    L = [
        begin
            case X of
                {Bin, asc} when is_binary(Bin) ->
                    <<"value ->> '", Bin/binary, "' ASC">>;
                {Bin, desc} when is_binary(Bin) ->
                    <<"value ->> '", Bin/binary, "' DESC">>;
                {F, asc} when is_atom(F) ->
                    Bin = list_to_bitstring(atom_to_list(F)),
                    <<"value ->> '", Bin/binary, "' ASC">>;
                {F, desc} when is_atom(F) ->
                    Bin = list_to_bitstring(atom_to_list(F)),
                    <<"value ->> '", Bin/binary, "' DESC">>
            end
        end || X <- Fields
    ],
    [<<" ORDER BY ">> | pgdb_utils:join_iolist(L, <<", ">>)].

    
% %% @private
% match_where_clause({'not', <<>>}) ->
%     [];

% match_where_clause([{'not', <<"{}">>}) ->
%     [];

% match_where_clause({'not', Json}) when is_binary(Json) ->
%     <<" not value @> ", $', Json/binary, $'>>;

% match_where_clause({'not', Pat}) ->
%     Json = jsx:encode(Pat),
%     <<" not value @> ", $', Json/binary, $'>>;

% match_where_clause(<<>>) ->
%     [];

% match_where_clause(<<"{}">>) ->
%     [];

% match_where_clause(Json) when is_binary(Json) ->
%     <<" value @> ", $', Json/binary, $'>>;

% match_where_clauses([Pat|T], Acc) ->
%     Json = jsx:encode(Pat),
%     <<" value @> ", $', Json/binary, $'>>.




%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec remove(binary(), binary(), binary()) -> ok | no_return().

remove(Schema, Table, Key) ->
    Q = [<<"delete from ">>, ?SCHEMA_TABLE(Schema, Table), <<" where key = $1">>],
    case pgdb:extended_query(Q, [Key]) of
        {ok, 1} ->
            ok;
        {error, Reason} ->
            error(Reason)
    end.



%% -----------------------------------------------------------------------------
%% @doc
%% @end
%% -----------------------------------------------------------------------------
-spec remove(binary(), binary(), binary(), list()) -> ok | no_return().

remove(Schema, Table, Key, Opts) ->
    Q = [<<"delete from ">>, ?SCHEMA_TABLE(Schema, Table), <<" where key = $1">>],
    case pgdb:extended_query(Q, [Key], Opts) of
        {ok, 1} ->
            ok;
        {error, Reason} ->
            error(Reason)
    end.




%% =============================================================================
%% PRIVATE
%% =============================================================================


%% @private
unwrap({ok, Rows}, Opts) ->
    Decode = decode_json(Opts),
    L = [maybe_decode(Decode, Value) || {{jsonb, Value}} <- Rows],
    case Decode of
        false ->
            pgdb_utils:to_json_iolist(L);
        _ ->
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
            {true, [return_maps, {labels, attempt_atom}]};
        {decode_json, PList} ->
            {true, PList};
        false ->
            {true, [return_maps, {labels, attempt_atom}]}
    end.
