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
%%%   call {unsubscribe, SubRef}                         -> ok
%%%   call status / links
-module(mem_macula_pool).
-behaviour(gen_server).

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-spec start_link(pid()) -> {ok, pid()}.
start_link(Mesh) ->
    gen_server:start_link(?MODULE, Mesh, []).

init(Mesh) ->
    {ok, #{mesh => Mesh}}.

handle_call({subscribe, Realm, Topic, Subscriber, _Opts}, _From, #{mesh := Mesh} = S) ->
    {reply, mem_macula_mesh:add_sub(Mesh, Realm, Topic, Subscriber), S};
handle_call({publish, Realm, Topic, Payload, _Opts}, _From, #{mesh := Mesh} = S) ->
    {reply, mem_macula_mesh:deliver(Mesh, Realm, Topic, Payload), S};
handle_call({unsubscribe, Ref}, _From, #{mesh := Mesh} = S) ->
    {reply, mem_macula_mesh:remove_sub(Mesh, Ref), S};
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
