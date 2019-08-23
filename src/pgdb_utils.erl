%% =============================================================================
%%  pgdb_utils.erl -
%%
%%  Copyright (c) 2016-2019 Ngineo Limited t/a Leapsight. All rights reserved.
%%
%%  Licensed under the Apache License, Version 2.0 (the "License");
%%  you may not use this file except in compliance with the License.
%%  You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%%  Unless required by applicable law or agreed to in writing, software
%%  distributed under the License is distributed on an "AS IS" BASIS,
%%  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%  See the License for the specific language governing permissions and
%%  limitations under the License.
%% =============================================================================


-module(pgdb_utils).

-export([tuple_fold/3]).
-export([var/1]).
-export([join_iolist/2]).
-export([to_json_iolist/1]).
-export([subst/2]).
-export([maybe_throw/1]).




-spec maybe_throw(Term) -> Term.
maybe_throw({error, Reason}) ->
    throw(Reason);
maybe_throw(Term) ->
    Term.


-spec tuple_fold(Fun :: function(), Acc0 :: any(), T :: tuple()) ->
    Acc1 :: any().
tuple_fold(Fun, Acc, T) ->
    Size = tuple_size(T),
    tuple_fold(Fun, Acc, Size, T).

%% @private
tuple_fold(_, Acc, 0, _) ->
    Acc;
tuple_fold(Fun, Acc0, Idx, T) ->
    Acc1 = Fun(element(Idx, T), Acc0),
    tuple_fold(Fun, Acc1, Idx - 1, T).


var(N) -> "$" ++ integer_to_list(N).

join_iolist([E], _) ->
    [E];
join_iolist(L, Str) ->
    join_iolist(L, Str, []).

join_iolist([], _, Acc) ->
    lists:reverse(Acc);
join_iolist([H | T], Str, []) ->
    join_iolist(T, Str, [H]);
join_iolist([H | T], Str, Acc) ->
    join_iolist(T, Str, [H, Str | Acc]).


to_json_iolist(L) ->
    lists:append([ [<<"[">>], join_iolist(L, <<",">>), [<<"]">>] ]).



subst(Fmt, []) -> lists:flatten(Fmt);
subst(Fmt, [{K, V} | T]) ->
    Fmt1 = re:replace(Fmt, "\\$" ++ atom_to_list(K), [V], [global, {return, list}]),
    subst(Fmt1, T).

