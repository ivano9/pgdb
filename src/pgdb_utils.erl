-module(pgdb_utils).

-export([tuple_fold/3]).
-export([var/1]).
-export([join_iolist/2]).
-export([subst/2]).
-export([uuid/0]).
-export([date_parser/0]).
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


subst(Fmt, []) -> lists:flatten(Fmt);
subst(Fmt, [{K, V} | T]) ->
    Fmt1 = re:replace(Fmt, "\\$" ++ atom_to_list(K), [V], [global, {return, list}]),
    subst(Fmt1, T).


uuid() ->
    list_to_bitstring(uuid:to_string(uuid:uuid4())).


%% A custom qdate parser for the ISO8601 dates where timezone == Z.
date_parser() ->
    fun
        (RawDate) when length(RawDate) == 20 ->
            try
                re:run(RawDate, "^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2})Z", [{capture, all_but_first, list}])
            of
                nomatch -> undefined;
                {match, [Y, M, D, H, I, S]} ->
                    Date = {list_to_integer(Y), list_to_integer(M), list_to_integer(D)},
                    Time = {list_to_integer(H), list_to_integer(I), list_to_integer(S)},
                    case calendar:valid_date(Date) of
                        true ->
                            {{Date, Time}, "UTC"};
                        false ->
                            undefined
                    end
            catch
                _:_ ->
                    undefined
            end;
        (_) ->
            undefined
    end.
