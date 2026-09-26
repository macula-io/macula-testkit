%%% @doc cth_skip_is_failure turns a skip nobody allowed into a failure, so
%%% `rebar3 ct' cannot exit 0 on a test that never ran.
%%%
%%% Each test runs a fixture suite from test/cth_fixtures through
%%% ct:run_test/1 and reads its result, {Ok, Failed, {UserSkipped,
%%% AutoSkipped}}. rebar3 ct exits 0 on user skips and 1 on failures and
%%% auto skips, so "no user skip left" is what the hook must deliver.
-module(cth_skip_is_failure_tests).
-include_lib("eunit/include/eunit.hrl").

%% Without the hook a skipped case is a user skip: the gap this closes.
a_user_skip_passes_without_the_hook_test() ->
    ?assertMatch({1, 0, {1, 0}}, run(case_skip_SUITE, no_hook)).

a_case_that_skips_itself_fails_test() ->
    ?assertMatch({1, 1, {0, 0}}, run(case_skip_SUITE, [])).

an_allowed_case_skip_stays_a_skip_test() ->
    Allow = [{case_skip_SUITE, skips_itself, "needs a live station; covered by the e2e suite"}],
    ?assertMatch({1, 0, {1, 0}}, run(case_skip_SUITE, [{allow, Allow}])).

a_skip_from_init_per_testcase_fails_test() ->
    ?assertMatch({0, 1, {0, 0}}, run(init_case_skip_SUITE, [])).

a_skip_from_init_per_suite_fails_every_case_test() ->
    {0, _Failed, {UserSkipped, AutoSkipped}} = run(suite_skip_SUITE, []),
    ?assertEqual(0, UserSkipped),
    ?assertEqual(2, AutoSkipped).

a_skip_from_init_per_group_fails_the_group_test() ->
    {0, _Failed, {UserSkipped, AutoSkipped}} = run(group_skip_SUITE, []),
    ?assertEqual(0, UserSkipped),
    ?assertEqual(1, AutoSkipped).

a_whole_suite_can_be_allowed_test() ->
    Allow = [{suite_skip_SUITE, '*', "needs Erlang distribution; run by ct_dist.sh"}],
    ?assertMatch({0, 0, {2, 0}}, run(suite_skip_SUITE, [{allow, Allow}])).

an_allowance_without_a_reason_is_refused_test() ->
    ?assertEqual({error, {allowance_without_reason, {case_skip_SUITE, skips_itself, ""}}},
                 cth_skip_is_failure:init(cth_skip_is_failure,
                                          [{allow, [{case_skip_SUITE, skips_itself, ""}]}])).

%% Run one fixture suite, with the hook (Opts) or without it (no_hook), and
%% return ct's {Ok, Failed, {UserSkipped, AutoSkipped}}.
run(Suite, Hook) ->
    Dir = filename:join(fixtures_dir(), "logs-" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    Result = ct:run_test([{dir, fixtures_dir()}, {suite, Suite}, {logdir, Dir},
                          {auto_compile, true}, {silent_connections, all},
                          {verbosity, 0}, {ct_hooks, hooks(Hook)}]),
    _ = file:del_dir_r(Dir),
    Result.

hooks(no_hook) -> [];
hooks(Opts) -> [{cth_skip_is_failure, Opts}].

fixtures_dir() ->
    filename:join(filename:dirname(code:which(?MODULE)), "cth_fixtures").
