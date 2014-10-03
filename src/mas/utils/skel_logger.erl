-module(skel_logger).
-behaviour(gen_server).

-include ("mas.hrl").

%% API
-export([start_link/1, report_result/2, close/0]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-record(state, {fds  = dict:new() :: dict:dict(),
                last_fitness = 0 :: number(),
                last_population = 0 :: number(),
                fights = 0 :: number(),
                reproductions = 0 :: number(),
                deaths = 0 :: number(),
                migrations = 0 :: number()}).

-type state() :: #state{}.

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link(config()) -> {ok, pid()}.
start_link(Cf) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [Cf], []).

-spec report_result(atom(),term()) -> ok.
report_result(Stat, Value) ->
    gen_server:cast(?MODULE, {Stat, Value}).

-spec close() -> ok.
close() ->
    gen_server:cast(whereis(?MODULE), close).

%%%===================================================================
%%% Callbacks
%%%===================================================================

-spec init(term()) -> {ok,state()}.
init([Cf]) ->
    timer:send_interval(Cf#config.write_interval, write),
%%     Dictionary = lists:foldl(fun(Atom, Dict) ->
%%                                      Filename = atom_to_list(Atom) ++ ".txt",
%%                                      {ok, Descriptor} = file:open(filename:join([Cf#config.log_dir, Filename]), [append, delayed_write, raw]),
%%                                      dict:store(Atom, Descriptor, Dict)
%%                              end, dict:new(),
%%                              [fitness, population, reproduction, migration, fight, death]),
    Dictionary = dict:new(),
    {ok, #state{fds = Dictionary}}.


-spec handle_call(term(),{pid(),term()},state()) -> {reply,term(),state()} |
                                                    {reply,term(),state(),hibernate | infinity | non_neg_integer()} |
                                                    {noreply,state()} |
                                                    {noreply,state(),hibernate | infinity | non_neg_integer()} |
                                                    {stop,term(),term(),state()} |
                                                    {stop,term(),state()}.
handle_call(_Request, _From, State) ->
    {reply, ok, State}.


-spec handle_cast(term(),state()) -> {noreply,state()} |
                                     {noreply,state(),hibernate | infinity | non_neg_integer()} |
                                     {stop,term(),state()}.
handle_cast({fitness, Value}, St) ->
    {noreply, St#state{last_fitness = Value}};

handle_cast({population, Value}, St) ->
    {noreply, St#state{last_population = Value}};

handle_cast({fight, Value}, St) ->
    OldValue = St#state.fights,
    {noreply, St#state{fights = Value + OldValue}};

handle_cast({reproduce, Value}, St) ->
    OldValue = St#state.reproductions,
    {noreply, St#state{reproductions = Value + OldValue}};

handle_cast({death, Value}, St) ->
    OldValue = St#state.deaths,
    {noreply, St#state{deaths = Value + OldValue}};

handle_cast({migration, Value}, St) ->
    OldValue = St#state.migrations,
    {noreply, St#state{migrations = Value + OldValue}};

handle_cast(close, State) ->
    {stop, normal, State}.


%% TODO not always standard_io
-spec handle_info(term(),state()) -> {noreply,state()} |
                                     {noreply,state(),hibernate | infinity | non_neg_integer()} |
                                     {stop,term(),state()}.
handle_info(write, St) ->
    file:write(standard_io, io_lib:fwrite("~p ~p\n", [fitness, St#state.last_fitness])),
    file:write(standard_io, io_lib:fwrite("~p ~p\n", [population, St#state.last_population])),
    file:write(standard_io, io_lib:fwrite("~p ~p\n", [death, St#state.deaths])),
    file:write(standard_io, io_lib:fwrite("~p ~p\n", [reproduction, St#state.reproductions])),
    file:write(standard_io, io_lib:fwrite("~p ~p\n", [fight, St#state.fights])),
    file:write(standard_io, io_lib:fwrite("~p ~p\n", [migration, St#state.migrations])),
    {noreply, St#state{fights = 0, deaths = 0, reproductions = 0, migrations = 0}}.

-spec terminate(term(),state()) -> no_return().
terminate(_Reason, St) ->
    close_files(St#state.fds).

-spec code_change(term(),state(),term()) -> {ok, state()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec write(file:io_device(),term()) -> ok.
write(FD, Value) ->
    file:write(standard_io, io_lib:fwrite("~p\n", [Value])).

-spec close_files(dict:dict()) -> list().
close_files(Dict) ->
    [file:close(FD) || {_Key, FD} <- dict:to_list(Dict)].
