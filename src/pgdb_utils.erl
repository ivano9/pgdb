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

