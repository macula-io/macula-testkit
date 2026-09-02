# macula-testkit

In-memory test support for **macula** consumers. Run the real macula pub/sub
stack in-process, with no QUIC, no certificates, and no station.

It provides:

1. **A drop-in loopback pool** (`mem_macula`): a gen_server that speaks the
   `macula_client` pool protocol, so `macula:publish(Pool, ...)` /
   `macula:subscribe(Pool, ...)` work **unchanged** against an in-memory mesh.
   A publish on one pool reaches subscribers on any pool in the cluster.
2. **A harness + assertions** (planned): stand up an N-node in-memory mesh and
   assert delivery, so any macula consumer can test its mesh behaviour fast.

It mirrors the command-side pattern: `evoq -> mem-evoq -> evoq-testkit` becomes
`macula -> macula-testkit (mem_macula) -> consumers`.

> The pool is the real seam, not the transport plugin. The SDK pub/sub path is
> hardcoded to QUIC below the pool (`macula_peering_conn`), so an in-memory
> `macula_net_transport` would not make `macula:publish/subscribe` work; the
> pool gen_server protocol is where the in-memory swap lives. See the proposal
> for the full finding.

```erlang
{ok, #{pools := [A, B]} = Cluster} = mem_macula:cluster(2),
{ok, _Ref} = macula:subscribe(B, Realm, Topic, self()),
ok = macula:publish(A, Realm, Topic, Fact),
%% self() receives {macula_event, _, Topic, Fact, _}
ok = mem_macula:stop(Cluster).
```

## Status

**Proposal stage.** Design lives in
[proposals/PROPOSAL_MACULA_TESTKIT.md](proposals/PROPOSAL_MACULA_TESTKIT.md).
Companion: [`hecate-services/hecate-testkit`](https://github.com/hecate-services/hecate-testkit)
composes this into the hecate service-boot path.

## License

Apache-2.0. See [LICENSE](LICENSE).
