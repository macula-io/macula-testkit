%%% @doc A Common Test hook that turns every skip nobody allowed into a failure.
%%%
%%% `rebar3 ct' exits 0 when a case skips itself (`{skip, Reason}' from the
%%% case, init_per_testcase, init_per_group or init_per_suite): the run
%%% reads as green although the test never ran. This hook rewrites such a
%%% skip into `{fail, {skip_not_allowed, Reason}}', so the case is reported
%%% as failed (or its group or suite as auto skipped) and rebar3 exits 1.
%%%
%%% A skip that is genuinely wanted is allowed explicitly, per suite, with
%%% the reason it is safe:
%%%
%%%   {ct_opts, [{ct_hooks, [{cth_skip_is_failure,
%%%       [{allow, [{my_SUITE, a_case, "why skipping it here is safe"},
%%%                 {dist_SUITE, '*', "needs distribution; run by ct_dist.sh"}]}]}]}]}.
%%%
%%% The second element is the case name, or '*' for any skip in that suite,
%%% including its init_per_suite and init_per_group. An allowance without a
%%% reason is refused when the hook starts, so the run does not start.
%%% @end
-module(cth_skip_is_failure).

-export([id/1, init/2]).
-export([post_init_per_suite/4, post_init_per_group/5,
         post_init_per_testcase/5, post_end_per_testcase/5]).

-type where() :: atom().
-type allowance() :: {module(), where(), string()}.

%% @doc The hook's id: one instance per run.
-spec id(term()) -> ?MODULE.
id(_Opts) -> ?MODULE.

%% @doc Read the allow-list. Every allowance must carry a non-empty reason.
-spec init(term(), [{allow, [allowance()]}]) -> {ok, [allowance()]} | {error, term()}.
init(_Id, Opts) ->
    Allow = proplists:get_value(allow, Opts, []),
    case [A || A <- Allow, not is_allowance(A)] of
        [] -> {ok, Allow};
        [Bad | _] -> {error, {allowance_without_reason, Bad}}
    end.

%% @doc A skip from init_per_suite skips every case in the suite.
-spec post_init_per_suite(module(), term(), term(), [allowance()]) -> {term(), [allowance()]}.
post_init_per_suite(Suite, _Config, Return, Allow) ->
    {judge(Suite, '*', Return, Allow), Allow}.

%% @doc A skip from init_per_group skips every case in the group.
-spec post_init_per_group(module(), atom(), term(), term(), [allowance()]) -> {term(), [allowance()]}.
post_init_per_group(Suite, _Group, _Config, Return, Allow) ->
    {judge(Suite, '*', Return, Allow), Allow}.

%% @doc A skip from init_per_testcase skips the case.
-spec post_init_per_testcase(module(), atom(), term(), term(), [allowance()]) -> {term(), [allowance()]}.
post_init_per_testcase(Suite, Case, _Config, Return, Allow) ->
    {judge(Suite, Case, Return, Allow), Allow}.

%% @doc A case that returns {skip, Reason} skipped itself.
-spec post_end_per_testcase(module(), atom(), term(), term(), [allowance()]) -> {term(), [allowance()]}.
post_end_per_testcase(Suite, Case, _Config, Return, Allow) ->
    {judge(Suite, Case, Return, Allow), Allow}.

%% A skip stays a skip only when an allowance names its suite and case (or
%% '*'); any other skip becomes a failure. Every other result passes through.
judge(Suite, Where, {skip, Reason} = Skip, Allow) ->
    keep_or_fail(is_allowed(Suite, Where, Allow), Skip, Reason);
judge(_Suite, _Where, Return, _Allow) ->
    Return.

keep_or_fail(true, Skip, _Reason) -> Skip;
keep_or_fail(false, _Skip, Reason) -> {fail, {skip_not_allowed, Reason}}.

is_allowed(Suite, Where, Allow) ->
    lists:any(fun({S, W, _Why}) -> S =:= Suite andalso (W =:= '*' orelse W =:= Where) end, Allow).

is_allowance({Suite, Where, Why}) when is_atom(Suite), is_atom(Where), is_list(Why) ->
    string:trim(Why) =/= "";
is_allowance(_) ->
    false.
