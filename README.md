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

## Skips are failures: `cth_skip_is_failure`

`rebar3 ct` exits 0 when a case skips itself, so a suite whose tests never ran
reads as green. This Common Test hook turns every skip nobody allowed into a
failure. Switch it on in `rebar.config`, and allow each wanted skip with the
reason it is safe:

```erlang
{ct_opts, [{ct_hooks, [{cth_skip_is_failure,
    [{allow, [{my_SUITE, a_case, "why skipping it here is safe"},
              {dist_SUITE, '*', "needs distribution; run by ct_dist.sh"}]}]}]}]}.
```

The second element names the case, or `'*'` for any skip in that suite,
including its `init_per_suite` and `init_per_group`. An allowance without a
reason stops the run before it starts. The hook needs only OTP's
`common_test`.

## Install

The library has no dependencies; bring your own macula (12.x) for `mem_macula`,
usually in the test profile:

```erlang
{profiles, [{test, [{deps, [{macula_testkit, "~> 0.2"}]}]}]}.
```

## Status

Pub/sub is proved against the real macula 12 facade by this repo's suite.
The design and the finding behind the pool seam are in
[PROPOSAL_MACULA_TESTKIT.md](https://github.com/macula-io/macula-testkit/blob/main/proposals/PROPOSAL_MACULA_TESTKIT.md).
`macula-services/mcl-testkit` composes this into the `mcl_om` service-boot
path for the mcl-* services.

## License

Apache-2.0. See [LICENSE](LICENSE).
