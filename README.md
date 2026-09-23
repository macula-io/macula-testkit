# macula-testkit

In-memory test support for **macula** consumers. Run the real macula pub/sub
stack in-process, with no QUIC, no certificates, and no station.

It provides a **drop-in loopback pool** (`mem_macula`): a gen_server that
speaks the `macula_client` pool protocol, so `macula:publish(Pool, ...)` and
`macula:subscribe(Pool, ...)` work **unchanged** against an in-memory mesh. A
publish on one pool reaches subscribers on any pool in the cluster.

Pub/sub only. RPC, advertise and streaming answer `{error, unsupported}`.

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

## Install

The library has no dependencies; bring your own macula (12.x), usually in the
test profile:

```erlang
{profiles, [{test, [{deps, [{macula_testkit, "~> 0.1"}]}]}]}.
```

## Status

Pub/sub is proved against the real macula 12 facade by this repo's suite.
The design and the finding behind the pool seam are in
[PROPOSAL_MACULA_TESTKIT.md](https://github.com/macula-io/macula-testkit/blob/main/proposals/PROPOSAL_MACULA_TESTKIT.md).
`macula-services/mcl-testkit` composes this into the `mcl_om` service-boot
path for the mcl-* services.

## License

Apache-2.0. See [LICENSE](LICENSE).
