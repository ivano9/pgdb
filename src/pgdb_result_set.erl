%% =============================================================================
%%
%% pgdb_result_set.erl
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


-module(pgdb_result_set).

-record(pgdb_result_set, {
    head :: [binary()],
    tuples :: [tuple()]
}).
-type pgdb_result_set() :: #pgdb_result_set{}.


-export([new/2]).
-export([head/1]).
-export([size/1]).
-export([rows_as_maps/1]).
-export([rows_as_tuples/1]).


%% @doc Creates a new result set
-spec new(Head :: list(), Tuples :: [tuple()]) -> pgdb_result_set().

new(Head, Tuples) when is_list(Head), is_list(Tuples) ->
    #pgdb_result_set{head = Head, tuples = Tuples}.


%% @doc Returns the head of the result set i.e. the projected attribute list
-spec head(RS :: pgdb_result_set()) -> list().

head(#pgdb_result_set{head = Head}) -> Head.


%% @doc Returns the number of rows in the result set.
-spec size(RS :: pgdb_result_set()) -> non_neg_integer().

size(#pgdb_result_set{tuples = Tuples}) ->
    length(Tuples).

%% @doc Returns a list of maps. The result set internally stores
%% rows as tuples. This function folds over the tuples,
%% lazily creating a map for each one. As such, this function is
%% more expensive than @see rows_as_tuples/1.
-spec rows_as_maps(RS :: pgdb_result_set()) -> [map()].

rows_as_maps(#pgdb_result_set{head = Head, tuples = Tuples}) ->
    [zip_to_map(Head, T) || T <- Tuples].


%% @doc Returns a list of tuples.
-spec rows_as_tuples(RS :: pgdb_result_set()) -> [tuple()].

rows_as_tuples(#pgdb_result_set{tuples = Ts}) -> Ts.


%% ============================================================================
%% PRIVATE
%% ============================================================================


%% @private
zip_to_map(L, T) when is_list(L), length(L) == tuple_size(T) ->
    zip_to_map(L, T, 1, #{}).

%% @private
zip_to_map([], _, _, Map) ->
    Map;

zip_to_map(['_' | Xs], T, Idx, Map) ->
    zip_to_map(Xs, T, Idx, Map);

zip_to_map([X | Xs], T, Idx, Map0) ->
    Map1 = maps:put(X, element(Idx, T), Map0),
    zip_to_map(Xs, T, Idx + 1, Map1).






