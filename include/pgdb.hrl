%% =============================================================================
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

-type condition()       ::  {condition_op(), db_field(), any()}.
-type condition_op()    ::  '=' | '<' | '>' | '!=' | '=<' | '>='.
-type db_field()        ::  binary().
-type error() 			:: 	{error, Reason :: any()}.
-type row()         	::  pgsql_connection:row().
