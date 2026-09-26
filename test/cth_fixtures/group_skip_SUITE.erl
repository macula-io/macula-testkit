%% Fixture for cth_skip_is_failure_tests: init_per_group skips a group.
-module(group_skip_SUITE).
-export([all/0, groups/0, init_per_group/2, end_per_group/2, in_group/1]).
all() -> [{group, slow}].
groups() -> [{slow, [], [in_group]}].
init_per_group(slow, _Config) -> {skip, "slow group disabled"}.
end_per_group(_Group, _Config) -> ok.
in_group(_Config) -> ok.
