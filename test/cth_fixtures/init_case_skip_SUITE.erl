%% Fixture for cth_skip_is_failure_tests: init_per_testcase skips a case.
-module(init_case_skip_SUITE).
-export([all/0, init_per_testcase/2, end_per_testcase/2, guarded/1]).
all() -> [guarded].
init_per_testcase(guarded, _Config) -> {skip, "feature flag off"}.
end_per_testcase(_Case, _Config) -> ok.
guarded(_Config) -> ok.
