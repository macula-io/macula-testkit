# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-10-17

The suite moves to macula 15 (wire 1.0), and the pool answers the two calls the
new wire adds to the publish and subscribe paths.

### Added

- `mem_macula_pool` answers `{await_registration, Registration}` with `ok`.
  macula 15 holds a subscription only once a station acknowledges it
  (macula#12): `macula:subscribe/4,5` registers, then waits through
  `macula_client:await_registration/4` for the station's REGISTER_ACK. This
  pool is the station, and the subscriber is already on the mesh by then, so
  there is nothing to wait for and nothing that can refuse. A macula 14 pool
  never receives the call, so the clause is additive there.
- `mem_macula_pool` answers `group_keyring` with an empty keyring. macula 15
  asks the pool for its sealed-group keyring on every publish
  (`macula_client:publish_checked/6`), to refuse a clear publish of a topic this
  node holds a group for. The pool holds no groups, so the keyring it answers
  with has no rows, `macula_group_keyring:policy/3` reads it as `none`, and the
  publish goes out clear as it did on macula 14. Sealed groups stay out of
  scope here, as RPC and advertise are.

Without those two clauses, four of the twelve cases in this repo's suite failed
against macula 15: every subscribing case with `{error, unsupported}` from the
registration wait, and every publishing case with a `function_clause` inside
`macula_group_keyring:policy/3`, which was handed that same error where it
expects the keyring.

### Changed

- The test profile builds against `macula ~> 15.6`, so a green run means
  `macula:publish/subscribe` still work unchanged over `mem_macula` on wire
  1.0. It was `macula ~> 12.1`.

## [0.2.0] - 2026-09-26

### Added

- `cth_skip_is_failure`: a Common Test hook that turns every skip nobody
  allowed into a failure. `rebar3 ct` exits 0 when a case skips itself
  (`{skip, Reason}` from the case, `init_per_testcase`, `init_per_group` or
  `init_per_suite`), so a suite whose tests never ran read as green
  (macula#43). With the hook the case fails, or its group or suite is auto
  skipped, and rebar3 exits 1. A wanted skip is allowed per suite and case
  (or `'*'` for the whole suite) with its reason; an allowance without a
  reason stops the run from starting. Proved by running fixture suites
  through `ct:run_test/1`.

## [0.1.0] - 2026-09-23

The first release on hex.

### Added

- `mem_macula`: an in-memory cluster of loopback pools that speak the
  `macula_client` pool protocol, so `macula:publish/4,5`,
  `macula:subscribe/4,5` and `macula:unsubscribe/2` work unchanged in process,
  with no station, no QUIC and no certificate. A publish on one pool reaches
  subscribers on every pool of the cluster, on the same realm and topic.
- The suite drives the real macula 12 facade against those pools.
- CI (lint, eunit, dialyzer in the pinned OTP 28.4.3 CI image) and a
  `publish-hex` workflow that publishes a pushed `v*` tag.

### Not supported

- RPC, advertise and streaming: the pool answers `{error, unsupported}`.
