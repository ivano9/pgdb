%% =============================================================================
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



-define(SELECT_SCHEMAS,
    "SELECT nsp.nspname, description \n"
    "FROM pg_namespace nsp \n"
    "LEFT OUTER JOIN pg_description des ON des.objoid=nsp.oid \n"
    "WHERE pg_get_userbyid(nspowner) = current_user \n"
    "ORDER BY nspname"
).

-define(SELECT_SCHEMA(Args),
    pgdb_utils:subst(
        "SELECT nsp.nspname, description \n"
        "FROM pg_namespace nsp \n"
        "LEFT OUTER JOIN pg_description des ON des.objoid=nsp.oid \n"
        "WHERE pg_get_userbyid(nspowner) = current_user \n"
        "AND nsp.nspname = '$id' \n"
        "ORDER BY nspname",
        Args)
).
