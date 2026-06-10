%%% @doc In-memory macula loopback: stand up an N-node mesh whose pools are
%%% drop-in replacements for real macula pools.
%%%
%%%   {ok, #{pools := [A, B]}} = mem_macula:cluster(2),
%%%   {ok, _} = macula:subscribe(B, Realm, Topic, self()),
%%%   ok      = macula:publish(A, Realm, Topic, Fact),
%%%   %% self() receives {macula_event, _, Topic, Fact, _}
%%%
%%% No QUIC, no station, no certificates.
-module(mem_macula).

-export([start_mesh/0, pool/1, cluster/1, stop/1]).

-spec start_mesh() -> {ok, pid()}.
start_mesh() ->
    mem_macula_mesh:start_link().

%% @doc A fresh pool bound to an existing mesh.
-spec pool(pid()) -> {ok, pid()}.
pool(Mesh) ->
    mem_macula_pool:start_link(Mesh).

%% @doc A mesh plus N pools bound to it. Returns the mesh and the pools.
-spec cluster(pos_integer()) -> {ok, #{mesh := pid(), pools := [pid()]}}.
cluster(N) when is_integer(N), N >= 1 ->
    {ok, Mesh} = start_mesh(),
    Pools = [begin {ok, P} = pool(Mesh), P end || _ <- lists:seq(1, N)],
    {ok, #{mesh => Mesh, pools => Pools}}.

-spec stop(#{mesh := pid(), pools := [pid()]}) -> ok.
stop(#{mesh := Mesh, pools := Pools}) ->
    _ = [gen_server:stop(P) || P <- Pools],
    gen_server:stop(Mesh),
    ok.
