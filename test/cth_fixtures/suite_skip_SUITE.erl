%% Fixture for cth_skip_is_failure_tests: init_per_suite skips every case.
-module(suite_skip_SUITE).
-export([all/0, init_per_suite/1, end_per_suite/1, one/1, two/1]).
all() -> [one, two].
init_per_suite(_Config) -> {skip, "no distribution"}.
end_per_suite(_Config) -> ok.
one(_Config) -> ok.
two(_Config) -> ok.
