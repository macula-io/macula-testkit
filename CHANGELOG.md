# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - unreleased

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
