%%% @doc A drop-in macula pool, in memory.
%%%
%%% Speaks exactly the gen_server protocol `macula_client' uses, so a consumer
%%% can call `macula:publish(Pool, ...)' / `macula:subscribe(Pool, ...)'
%%% unchanged against one of these and it just works. The pool delegates to the
%%% shared mesh; pub/sub, routing, and QUIC are not involved.
%%%
%%% Protocol reproduced (from macula_client.erl):
%%%   call {publish,   Realm, Topic, Payload, Opts}     -> ok
%%%   call {subscribe, Realm, Topic, Subscriber, Opts}  -> {ok, SubRef}
%%%                                                      | {error, Reason}
%%%   call {await_registration, Registration}            -> ok
%%%   call {unsubscribe, SubRef}                         -> ok
%%%   call group_keyring                                 -> the empty keyring
%%%   call status / links
-module(mem_macula_pool).
-behaviour(gen_server).

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-spec start_link(pid()) -> {ok, pid()}.
start_link(Mesh) ->
    gen_server:start_link(?MODULE, Mesh, []).

init(Mesh) ->
    {ok, #{mesh => Mesh, keyring => empty_keyring()}}.

%% macula (15 onwards, 18 today) asks the pool for its group keyring on every publish
%% (`macula_client:publish_checked/6'), to refuse a clear publish of a topic
%% this node holds a sealed group for. This pool holds no groups, so the
%% keyring is its shape with no rows in it: `macula_group_keyring:policy/3'
%% reads it as `none', and the publish goes out clear, as it did on macula 14.
%% Sealed groups stay out of scope here, as RPC and advertise are.
%%
%% The table is unnamed (only this handle names it) and created by the pool,
%% so it dies with the pool. The SDK's `policy/3' reads it from the caller's
%% process, which a `protected' table allows.
empty_keyring() ->
    #{table => ets:new(?MODULE, [protected, set, {read_concurrency, true}])}.

handle_call({subscribe, Realm, Topic, Subscriber, Opts}, _From, #{mesh := Mesh} = S) ->
    {reply, subscribed(declared(maps:get(sources, Opts, undefined)), Mesh, Realm, Topic, Subscriber), S};
handle_call({publish, Realm, Topic, Payload, _Opts}, _From, #{mesh := Mesh} = S) ->
    {reply, mem_macula_mesh:deliver(Mesh, Realm, Topic, Payload), S};
handle_call({await_registration, _Registration}, _From, S) ->
    %% macula (15 onwards, 18 today; wire 1.0) holds a subscription only once
    %% a station acknowledges it: `macula:subscribe/5' registers, then waits here
    %% through `macula_client:await_registration/4' (macula#12). This pool is
    %% the station: `{subscribe, ...}' above has already put the subscriber on
    %% the mesh, so there is nothing left to wait for and nothing that can
    %% refuse. macula 14 never sends this call, so the clause is additive
    %% there.
    {reply, ok, S};
handle_call({unsubscribe, Ref}, _From, #{mesh := Mesh} = S) ->
    {reply, mem_macula_mesh:remove_sub(Mesh, Ref), S};
handle_call(group_keyring, _From, #{keyring := Keyring} = S) ->
    {reply, Keyring, S};
handle_call(status, _From, S) ->
    {reply, {ok, #{transport => mem_macula, healthy => true}}, S};
handle_call(links, _From, S) ->
    {reply, {ok, []}, S};
handle_call(_Req, _From, S) ->
    %% RPC / advertise / streaming are out of spike scope.
    {reply, {error, unsupported}, S}.

%% A subscription declares who may deliver to it, and one that names none is
%% refused before it exists: macula 18's pool does this in its subscribe
%% handler (macula_client:add_subscription/5, through
%% macula_subscriber_sources:declared/3), not in `macula:subscribe/5', so this
%% pool must too, or a consumer's missing `sources' passes here and fails on
%% the real mesh. The same shapes and reasons as 18.3. `members' and
%% `{org, Org}' need the realm's key on a real pool; the in-memory mesh is its
%% own realm, so here they always have one. Delivery is NOT filtered by the
%% sources: see the README, "What the pool does not model".
declared(undefined) -> {error, {sources, required}};
declared(open) -> ok;
declared(members) -> ok;
declared({org, Org}) when is_binary(Org), byte_size(Org) > 0 -> ok;
declared({org, _NotAnOrg}) -> {error, {source_class, {org, invalid}}};
declared({nodes, []}) -> {error, {source_class, {nodes, empty}}};
declared({nodes, NodeIds}) when is_list(NodeIds) -> node_ids(NodeIds);
declared({nodes, _NotAList}) -> {error, {source_class, {nodes, not_a_list}}};
declared(Declaration) -> {error, {source_class, {unknown, Declaration}}}.

node_ids([]) -> ok;
node_ids([<<_:256>> | Rest]) -> node_ids(Rest);
node_ids([_NotANodeId | _]) -> {error, {source_class, {nodes, not_node_ids}}};
node_ids(_Improper) -> {error, {source_class, {nodes, not_a_list}}}.

subscribed(ok, Mesh, Realm, Topic, Subscriber) -> mem_macula_mesh:add_sub(Mesh, Realm, Topic, Subscriber);
subscribed({error, _} = Refused, _Mesh, _Realm, _Topic, _Subscriber) -> Refused.

handle_cast(_Msg, S) ->
    {noreply, S}.

handle_info(_Info, S) ->
    {noreply, S}.

terminate(_Reason, _S) ->
    ok.
