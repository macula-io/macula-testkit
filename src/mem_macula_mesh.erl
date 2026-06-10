%%% @doc The shared in-memory fabric behind a mem_macula cluster.
%%%
%%% Holds every subscription across all pools in the cluster and fans a publish
%%% out to the matching subscribers, reproducing the macula pub/sub contract:
%%% subscribers receive `{macula_event, SubRef, Topic, Payload, Meta}`. A
%%% publish on one pool reaches subscribers registered through any pool, which
%%% is what gives the cluster mesh-broadcast semantics with no QUIC and no
%%% station.
-module(mem_macula_mesh).
-behaviour(gen_server).

-export([start_link/0, add_sub/4, remove_sub/2, deliver/4, stop/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

start_link() ->
    gen_server:start_link(?MODULE, [], []).

-spec add_sub(pid(), binary(), binary(), pid()) -> {ok, reference()}.
add_sub(Mesh, Realm, Topic, Pid) ->
    gen_server:call(Mesh, {add_sub, Realm, Topic, Pid}).

-spec remove_sub(pid(), reference()) -> ok.
remove_sub(Mesh, Ref) ->
    gen_server:call(Mesh, {remove_sub, Ref}).

-spec deliver(pid(), binary(), binary(), term()) -> ok.
deliver(Mesh, Realm, Topic, Payload) ->
    gen_server:call(Mesh, {deliver, Realm, Topic, Payload}).

stop(Mesh) ->
    gen_server:stop(Mesh).

%%--------------------------------------------------------------------

init([]) ->
    {ok, #{subs => [], seq => 0}}.

handle_call({add_sub, Realm, Topic, Pid}, _From, #{subs := Subs} = S) ->
    Ref  = make_ref(),
    MRef = erlang:monitor(process, Pid),
    Sub  = #{realm => Realm, topic => Topic, pid => Pid, ref => Ref, mref => MRef},
    {reply, {ok, Ref}, S#{subs := [Sub | Subs]}};
handle_call({remove_sub, Ref}, _From, #{subs := Subs} = S) ->
    {Drop, Keep} = lists:partition(fun(#{ref := R}) -> R =:= Ref end, Subs),
    _ = [erlang:demonitor(MRef, [flush]) || #{mref := MRef} <- Drop],
    {reply, ok, S#{subs := Keep}};
handle_call({deliver, Realm, Topic, Payload}, _From, #{subs := Subs, seq := Seq0} = S) ->
    Seq  = Seq0 + 1,
    Meta = #{realm => Realm, publisher => mem, seq => Seq, delivered_via => mem_macula},
    _ = [ Pid ! {macula_event, Ref, Topic, Payload, Meta}
          || #{realm := R, topic := T, pid := Pid, ref := Ref} <- Subs,
             R =:= Realm, T =:= Topic ],
    {reply, ok, S#{seq := Seq}};
handle_call(_Req, _From, S) ->
    {reply, {error, unsupported}, S}.

handle_cast(_Msg, S) ->
    {noreply, S}.

%% Drop a subscriber's entries when it dies (matches the real pool's
%% subscriber-DOWN cleanup).
handle_info({'DOWN', MRef, process, _Pid, _Reason}, #{subs := Subs} = S) ->
    Keep = [Sub || #{mref := M} = Sub <- Subs, M =/= MRef],
    {noreply, S#{subs := Keep}};
handle_info(_Info, S) ->
    {noreply, S}.

terminate(_Reason, _S) ->
    ok.
