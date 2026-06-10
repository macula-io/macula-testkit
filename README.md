# macula-testkit

In-memory test support for **macula** consumers. Run the real macula pub/sub
stack in-process, with no QUIC, no certificates, and no station.

It provides two things:

1. **A loopback transport** (`mem_macula`): an in-memory implementation of the
   existing `macula_net_transport` behaviour. The real peering, routing, and
   pub/sub run unchanged on top; only the bytes-on-the-wire layer is swapped for
   in-process message passing.
2. **A harness + assertions**: stand up an N-node in-memory mesh, publish, and
   assert delivery, so any macula consumer can test its mesh behaviour fast.

It mirrors the command-side pattern: `evoq -> mem-evoq -> evoq-testkit` becomes
`macula -> macula-testkit (mem_macula) -> consumers`.

> The loopback transport is kept as a distinct module (`mem_macula`) from the
> assertion helpers on purpose: if it ever earns non-test reuse (a real
> same-host loopback transport for dev), it lifts cleanly into its own
> `mem-macula` package, exactly as `mem-evoq` is a real in-memory event store,
> not only a test tool.

## Status

**Proposal stage.** Design lives in
[proposals/PROPOSAL_MACULA_TESTKIT.md](proposals/PROPOSAL_MACULA_TESTKIT.md).
Companion: [`hecate-services/hecate-testkit`](https://codeberg.org/hecate-services/hecate-testkit)
composes this into the hecate service-boot path.

## License

Apache-2.0. See [LICENSE](LICENSE).
