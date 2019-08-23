%% =============================================================================
%%
%% pgdb_object_sec.erl
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

-module(pgdb_object_spec).

-type object_spec() :: map().

-export([add_column/6]).
-export([column_default/2]).
-export([column_index/2]).
-export([column_is_read_only/2]).
-export([column_names/1]).
-export([column_type/2]).
-export([eval_column_default/2]).
-export([mutable_column_names/1]).
-export([new/1]).
-export([mod/1]).
-export([primary_key/1]).
-export([set_primary_key/2]).
-export([size/1]).
-export([table_name/1]).
-export([qualifier/1]).
-export([is_immutable/1]).

-export_type([object_spec/0]).


new(Table) ->
    #{
        table => Table
    }.

mod(#{mod := Val}) ->
    Val.

table_name(#{table := Val}) ->
    Val.


primary_key(#{primary_key := Val}) ->
    Val.


set_primary_key(S, Val) ->
    S#{primary_key => Val}.


is_immutable(Spec) ->
    maps:get(is_immutable, Spec, false).


size(#{columns := Set}) ->
    ordsets:size(Set).

qualifier(Spec) ->
    maps:get(qualifier, Spec, undefined).


add_column(
    #{columns := Set0} = Spec0, Name, Index, IsReadOnly, Default, Datatype)
    when is_binary(Name), Index > 0, is_boolean(IsReadOnly) ->
    Col = #{
        index => Index,
        is_read_only => IsReadOnly,
        default => Default,
        type => Datatype
    },
    Spec1 = maps:put(Name, Col, Spec0),
    maps:put(columns, ordsets:add_element({Index, Name}, Set0), Spec1).


%% @doc Returns the list of column names sorted by index.
column_names(#{columns := Set}) ->
    [N || {_Idx, N} <- ordsets:to_list(Set)].


column_index(Spec, Name) ->
    maps:get(index, maps:get(Name, Spec)).


column_is_read_only(Spec, Name) ->
    maps:get(is_read_only, maps:get(Name, Spec)).


column_default(Spec, Name) ->
    maps:get(default, maps:get(Name, Spec), null).


column_type(Spec, Name) ->
    maps:get(type, maps:get(Name, Spec)).


eval_column_default(Spec, Name) ->
    Val = column_default(Spec, Name),
    case is_function(Val) of
        true -> Val();
        false -> Val
    end.


mutable_column_names(Spec) ->
    Fun = fun({_I, N}, Acc) ->
        case column_is_read_only(Spec, N) of
            true -> Acc;
            false -> [N | Acc]
        end
          end,
    lists:reverse(ordsets:fold(Fun, [], maps:get(columns, Spec))).

