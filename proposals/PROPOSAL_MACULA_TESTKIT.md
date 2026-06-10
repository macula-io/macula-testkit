# Proposal: macula-testkit

**Status:** Draft / Concept &nbsp;·&nbsp; **Date:** 2026-06-10 &nbsp;·&nbsp; **First consumer:** hecate-dronex (via hecate-testkit)

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

## 3. Key finding: the seam already exists

`macula` already defines `macula_net_transport`, described in-source as the
"transport plugin contract for macula-net" (QUIC, BATMAN-adv, LoRa, satellite
all implement it). `macula_net_transport_quic` is one implementation.

So the in-memory transport is **just another plugin**, not SDK surgery. The real
macula pub/sub, routing, and dedup run unchanged on top; only the wire layer is
swapped. That makes the double faithful (it exercises real routing) and cheap
(no QUIC, no certs, no network). This is the exact analogue of `mem-evoq` being a
second `evoq` adapter.

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

## 5. Altitude decision

Two options for the loopback: (a) a transport-plugin loopback (an in-memory
`macula_net_transport`, with the real routing stack above it) or (b) a
facade-level fake pool (publish wired straight to subscribers, routing
bypassed). Recommend **(a)**: the seam exists, it exercises the real pub/sub, and
it catches routing regressions a facade fake would mask. Fall back to (b) only if
standing up the in-process station proves heavy.

## 6. Scope boundaries

- **Pub/sub + RPC first** (what services use). DHT records and streaming come
  later, behind the same transport seam.
- Reusable by any macula consumer (mpong-bot, macula-rag, git-remote-mesh,
  macula-mcp); it must not depend on `hecate_om`.

## 7. First step

Spike the in-memory `macula_net_transport`: stand up a 2-node loopback cluster
and prove `publish` on one node reaches `subscribe` on the other through the real
stack. Once that holds, `hecate-services/hecate-testkit` composes it into the
service-boot path, and the hecate-dronex over-mesh test lands on top.

See the companion proposal in
[`hecate-services/hecate-testkit`](https://codeberg.org/hecate-services/hecate-testkit/src/branch/main/proposals/PROPOSAL_HECATE_TESTKIT.md).
