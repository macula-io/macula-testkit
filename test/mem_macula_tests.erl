%%% @doc Spike: prove a mem_macula pool is a drop-in for a real macula pool.
%%%
%%% These drive the REAL macula facade (`macula:publish/4`, `macula:subscribe/4`)
%%% against in-memory pools. If they pass, a consumer (a hecate service, DroneX)
%%% can run its full pub/sub over mem_macula with no station, no QUIC, no certs,
%%% and no code change.
-module(mem_macula_tests).
-include_lib("eunit/include/eunit.hrl").

%% A 32-byte realm tag (the only thing macula's guards require of it).
-define(REALM, <<0:256>>).

%% A fact published on pool A reaches a subscriber on pool B, through the real
%% facade. This is the cross-node mesh broadcast, in memory.
cross_node_pubsub_test() ->
    {ok, #{pools := [A, B]} = Cluster} = mem_macula:cluster(2),
    Topic = <<"airspace/leuven/contact_observed">>,
    {ok, _Ref} = macula:subscribe(B, ?REALM, Topic, self()),
    Fact = #{fact => <<"airspace.contact_observed">>, drone => #{id => <<"bogey-1">>}},
    ok = macula:publish(A, ?REALM, Topic, Fact),
    receive
        {macula_event, _Sub, T, Payload, Meta} ->
            ?assertEqual(Topic, T),
            ?assertEqual(Fact, Payload),
            ?assert(is_map(Meta))
    after 1000 ->
        erlang:error(no_delivery)
    end,
    ok = mem_macula:stop(Cluster).

%% A subscriber hears only its own topic.
topic_isolation_test() ->
    {ok, #{pools := [A, B]} = Cluster} = mem_macula:cluster(2),
    {ok, _} = macula:subscribe(B, ?REALM, <<"topic/x">>, self()),
    ok = macula:publish(A, ?REALM, <<"topic/y">>, #{n => 1}),
    receive
        {macula_event, _, <<"topic/y">>, _, _} -> erlang:error(unexpected_delivery)
    after 200 ->
        ok
    end,
    ok = mem_macula:stop(Cluster).

%% subscribe returns the documented {ok, reference()} shape.
subscribe_returns_ref_test() ->
    {ok, #{pools := [A]} = Cluster} = mem_macula:cluster(1),
    Result = macula:subscribe(A, ?REALM, <<"t">>, self()),
    ?assertMatch({ok, Ref} when is_reference(Ref), Result),
    ok = mem_macula:stop(Cluster).

%% A second subscriber on a different pool also receives the same publish
%% (fan-out across the cluster).
fanout_to_two_pools_test() ->
    {ok, #{pools := [A, B, C]} = Cluster} = mem_macula:cluster(3),
    Topic = <<"airspace/leuven/track_confirmed">>,
    Self = self(),
    P1 = spawn_link(fun() -> relay(Self, b) end),
    P2 = spawn_link(fun() -> relay(Self, c) end),
    {ok, _} = macula:subscribe(B, ?REALM, Topic, P1),
    {ok, _} = macula:subscribe(C, ?REALM, Topic, P2),
    ok = macula:publish(A, ?REALM, Topic, #{track_id => <<"track-1">>}),
    ?assertEqual([b, c], lists:sort([recv_tag(), recv_tag()])),
    ok = mem_macula:stop(Cluster).

%%--------------------------------------------------------------------

relay(Parent, Tag) ->
    receive
        {macula_event, _, _, _, _} -> Parent ! {got, Tag}
    after 1000 ->
        Parent ! {got, timeout}
    end.

recv_tag() ->
    receive {got, Tag} -> Tag after 1500 -> timeout end.
