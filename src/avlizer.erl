%%%-----------------------------------------------------------------------------
%%%
%%% Copyright (c) 2018-2019 Klarna Bank AB (publ).
%%%
%%% This file is provided to you under the Apache License,
%%% Version 2.0 (the "License"); you may not use this file
%%% except in compliance with the License.  You may obtain
%%% a copy of the License at
%%%
%%%   http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing,
%%% software distributed under the License is distributed on an
%%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%%% KIND, either express or implied.  See the License for the
%%% specific language governing permissions and limitations
%%% under the License.
%%%-----------------------------------------------------------------------------

-module(avlizer).

%% application callbacks
-export([ start/2
        , stop/1
        ]).

start(_StartType, _StartArgs) ->
  set_envs(),
  avlizer_sup:start_link().

stop(_State) -> ok.

set_envs() ->
  Vars0 = application:get_env(?APPLICATION, avlizer_confluent, #{}),
  Vars1 = maybe_put_schema_registry_url(Vars0),
  Vars2 = maybe_put_schema_registry_auth(Vars1),
  application:set_env(?APPLICATION, avlizer_confluent, Vars2).

maybe_put_schema_registry_url(Map) ->
  SchemaRegistryURL = osenv("AVLIZER_CONFLUENT_SCHEMAREGISTRY_URL", false),
  case SchemaRegistryURL of
    false -> Map;
    URL -> maps:put(schema_registry_url, URL, Map)
  end.

maybe_put_schema_registry_auth(Map) ->
  SchemaRegistryAuthMechanism = osenv("AVLIZER_CONFLUENT_SCHEMAREGISTRY_AUTH_MECHANISM", false),
  SchemaRegistryAuthUsername = osenv("AVLIZER_CONFLUENT_SCHEMAREGISTRY_AUTH_USERNAME", false),
  SchemaRegistryAuthPassword = osenv("AVLIZER_CONFLUENT_SCHEMAREGISTRY_AUTH_PASSWORD", false),

  Auth = {maybe_string_to_atom(SchemaRegistryAuthMechanism), SchemaRegistryAuthUsername, SchemaRegistryAuthPassword},

  Map0 = case lists:member(false, tuple_to_list(Auth)) of
    true -> Map;
    false -> maps:put(schema_registry_auth, Auth, Map)
  end,
  
  maybe_read_auth_file(Map0).

maybe_string_to_atom(false) -> false;
maybe_string_to_atom(Env) -> list_to_atom(Env).

maybe_read_auth_file(#{schema_registry_auth := {_Mechanism, File}} = Vars) ->
  case file:read_file(File) of
    {ok, Binary} -> maybe_read_auth_file(Vars, Binary);
    Error -> Error
  end;
maybe_read_auth_file(Vars) -> Vars.

maybe_read_auth_file(#{schema_registry_auth := {Mechanism, File}} = Vars, Binary) ->
  Lines = binary:split(Binary, <<"\n">>),
  case Lines of
    [Username, Password] -> 
      Auth = {Mechanism, binary_to_list(Username), binary_to_list(Password)},
      maps:put(schema_registry_auth, Auth, Vars);
    _Malformed -> 
      error_logger:error_msg("Malformed authorization file ~s", [File]),
      Vars
  end.

osenv(Name, Default) ->
  case os:getenv(Name) of
    "" -> Default; %% VAR=""
    false -> Default; %% not set
    Val -> Val
  end.

%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
