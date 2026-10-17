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

%% macula 15 asks the pool for its group keyring on every publish
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

handle_call({subscribe, Realm, Topic, Subscriber, _Opts}, _From, #{mesh := Mesh} = S) ->
    {reply, mem_macula_mesh:add_sub(Mesh, Realm, Topic, Subscriber), S};
handle_call({publish, Realm, Topic, Payload, _Opts}, _From, #{mesh := Mesh} = S) ->
    {reply, mem_macula_mesh:deliver(Mesh, Realm, Topic, Payload), S};
handle_call({await_registration, _Registration}, _From, S) ->
    %% macula 15 (wire 1.0) holds a subscription only once a station
    %% acknowledges it: `macula:subscribe/4,5' registers, then waits here
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

handle_cast(_Msg, S) ->
    {noreply, S}.

handle_info(_Info, S) ->
    {noreply, S}.

terminate(_Reason, _S) ->
    ok.
