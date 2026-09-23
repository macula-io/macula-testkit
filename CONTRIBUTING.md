# Contributing

Trunk-based. Commit directly to `main`. No PRs.

## Build

```bash
rebar3 lint
rebar3 eunit      # drives the real macula facade against mem_macula
rebar3 dialyzer
```

## Style

- Erlang: `warnings_as_errors`, dialyzer clean.
- The library itself has no dependencies. macula appears only in the test
  profile, which is where the "drop-in for a real pool" claim is proved.
  Keep it that way: a consumer brings its own macula.

## Releasing

Bump `vsn` in `src/macula_testkit.app.src`, add the CHANGELOG entry, commit,
and push a `vX.Y.Z` tag. The `publish-hex` workflow publishes that tag; nobody
publishes by hand.

## Issues

https://github.com/macula-io/macula-testkit/issues
