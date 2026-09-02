# Proposal: macula-testkit

**Status:** Spike complete (loopback proven) &nbsp;·&nbsp; **Date:** 2026-06-10 &nbsp;·&nbsp; **First consumer:** hecate-dronex (via hecate-testkit)

## 1. Problem

A macula consumer cannot today test its mesh behaviour without a live station,
realm, and certificate. "Did my service publish the right fact, and did a
subscriber on another node receive it?" requires standing up real infrastructure
over QUIC. So the integration that matters most (facts crossing the mesh) has no
fast, hermetic test.

This blocks, concretely, the hecate-dronex over-mesh loop: `observe_remote_id`
publishes `airspace.contact_observed`, `fuse_airspace` consumes it and publishes
`airspace.track_confirmed`, `query_detection_quality` scores it. None of that
fact-crossing has a test.

## 2. Principle: mirror the command-side pattern

The command side already proves the shape:

```
evoq    →  mem-evoq          →  evoq-testkit
(store)    (in-memory double)    (harness + assertions)
```

Do the same for the mesh, with `macula-testkit` as the leaf test package that
holds both the double and the harness:

```
macula  →  macula-testkit
(SDK)      (mem_macula loopback transport + harness)
```

## 3. Key finding (revised by the spike): the seam is the pool, not the transport

The original assumption was that the pluggable `macula_net_transport` behaviour
(QUIC, BATMAN-adv, LoRa, ...) was the injection point. The spike disproved this
for pub/sub: `macula_net_transport` serves the macula-net/dist layer, but the
SDK pub/sub path (`macula:publish` -> `macula_pubsub` -> `macula_client` ->
`macula_peering_conn`) is **hardcoded to `macula_quic`**. The peering connection
has no transport seam, so an in-memory `macula_net_transport` would not make
`macula:publish/subscribe` work in process.

The real injectable seam is one layer up: **the pool**. `macula_client` is a
gen_server, and the facade reduces to a small protocol (read from
`macula_client.erl`):

```
gen_server:call(Pool, {publish,   Realm, Topic, Payload, Opts})    -> ok
gen_server:call(Pool, {subscribe, Realm, Topic, Subscriber, Opts}) -> {ok, Ref}
Subscriber ! {macula_event, Ref, Topic, Payload, Meta}
```

So a drop-in pool process (`mem_macula`) lets a consumer call
`macula:publish(Pool, ...)` / `macula:subscribe(Pool, ...)` **unchanged** against
an in-memory mesh. That is what the spike built.

## 4. What macula-testkit provides

**`mem_macula` (the loopback transport).** An in-memory `macula_net_transport`
plus the minimal in-process station/router wiring so two or more in-process
nodes exchange envelopes. Kept as a distinct module from the harness so it can be
extracted into its own `mem-macula` package if it earns non-test reuse (the way
`mem-evoq` is a real in-memory store, not only a test tool).

**Harness + assertions.** Stand up an N-node in-memory mesh and assert delivery.

It also **owns the canonical delivery contract**: the `{macula_event, Ref,
Topic, Payload, Meta}` tuple shape and the CBOR-term-not-JSON rule. Pinning that
here once prevents the kind of 4-vs-5-element ambiguity that has forced
defensive `handle_info` clauses in consumers.

Sketch:

```erlang
{ok, [PoolA, PoolB]} = macula_testkit:cluster(2),
ok = macula:publish(PoolA, Realm, Topic, Fact),
%% PoolB's subscriber receives {macula_event, _, Topic, Fact, _}
ok = macula_testkit:assert_delivered(PoolB, Topic,
       fun(F) -> is_map(F) end).
```

## 5. Altitude (resolved by the spike): pool-protocol drop-in

Two altitudes were considered: (a) a transport-plugin loopback (real routing
above an in-memory transport) and (b) a pool-level drop-in (deliver in memory,
routing bypassed). **(a) is not available without an SDK refactor**: making
`macula_peering_conn` use a pluggable transport instead of hardcoded
`macula_quic`. That is worthwhile future work (it would let mem_macula exercise
real routing, bloom, and dedup) but is out of scope for testing consumers.

The spike implemented **(b)** and it works: `mem_macula` is a gen_server that
speaks the pool protocol, driven by the real `macula:publish/4` /
`macula:subscribe/4`. **4 tests green** (cross-node delivery, topic isolation,
3-pool fan-out, the `{ok, Ref}` contract), no station, no QUIC, no certs.

Tradeoff recorded: mem_macula does not exercise macula's own routing/dedup/bloom.
Tests of those still need real stations or the future peering transport seam.
For testing *consumers* (a hecate service's fact-crossing), the contract-level
drop-in is exactly right.

## 6. Scope boundaries

- **Pub/sub + RPC first** (what services use). DHT records and streaming come
  later, behind the same transport seam.
- Reusable by any macula consumer (mpong-bot, macula-rag, git-remote-mesh,
  macula-mcp); it must not depend on `hecate_om`.

## 7. Next steps

The spike (`src/mem_macula*.erl`, `test/mem_macula_tests.erl`) is done: a
2+ node in-memory cluster with drop-in pools, proven via the real facade.
Remaining:

1. Round out the pool protocol where consumers need it: `unsubscribe` (done),
   `call`/`advertise` (RPC) and `status`/`links` if a consumer asserts on them.
2. A small `macula_testkit` harness module (`cluster/1`, `assert_delivered/3`).
3. `hecate-services/hecate-testkit` composes `mem_macula` into the
   `hecate_om:boot` path, and the hecate-dronex over-mesh test lands on top.

Deferred (separate, larger): a peering transport seam so a loopback can run the
real routing stack (full-fidelity routing/dedup tests).

See the companion proposal in
[`hecate-services/hecate-testkit`](https://github.com/hecate-services/hecate-testkit/blob/main/proposals/PROPOSAL_HECATE_TESTKIT.md).
