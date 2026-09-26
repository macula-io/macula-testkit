%% Fixture for cth_skip_is_failure_tests: a case that skips itself.
-module(case_skip_SUITE).
-export([all/0, skips_itself/1, passes/1]).
all() -> [skips_itself, passes].
skips_itself(_Config) -> {skip, "no station reachable"}.
passes(_Config) -> ok.
