%% @author jstypka <jasieek@student.agh.edu.pl>
%% @version 1.1
%% @doc Model sekwencyjny, gdzie agenci sa na stale podzieleni w listach reprezentujacych wyspy.

-module(sequential_lists).
-export([start/5, start/0, start/1]).

-record(counter,{fight = 0 :: non_neg_integer(),
                 reproduction = 0 :: non_neg_integer(),
                 migration = 0 :: non_neg_integer(),
                 death = 0 :: non_neg_integer()}).

-type agent() :: {Solution::genetic:solution(), Fitness::float(), Energy::pos_integer()}.
-type island() :: [agent()].
-type counter() :: #counter{}.

%% ====================================================================
%% API functions
%% ====================================================================
-spec start() -> ok.
start() ->
    file:make_dir("tmp"),
    start(40,5000,2,mesh,"tmp").

-spec start(list()) -> ok.
start([A,B,C,D,E]) ->
    start(list_to_integer(A),
          list_to_integer(B),
          list_to_integer(C),
          list_to_atom(D),E).

-spec start(ProblemSize::pos_integer(), Time::pos_integer(), Islands::pos_integer(), Topology::topology:topology(), Path::string()) -> ok.
start(ProblemSize,Time,Islands,Topology,Path) ->
    io:format("{Model=sequential_lists,ProblemSize=~p,Time=~p,Islands=~p,Topology=~p}~n",[ProblemSize,Time,Islands,Topology]),
    misc_util:seedRandom(),
    misc_util:clearInbox(),
    topology:start_link(Islands,Topology),
    logger:start_link({sequential,Islands},Path),
    Environment = config:agent_env(),
    InitIslands = [Environment:initial_population() || _ <- lists:seq(1,Islands)],
    timer:send_after(Time,theEnd),
    timer:send_after(config:writeInterval(),write),
    {_Time,_Result} = timer:tc(fun loop/2, [InitIslands,#counter{}]),
    topology:close(),
    logger:close().

%% ====================================================================
%% Internal functions
%% ====================================================================

%% @doc Glowa petla programu. Kazda iteracja powoduje ewolucje nowej generacji osobnikow.
-spec loop([island()],counter()) -> float().
loop(Islands,Counter) ->
    receive
        write ->
            logger:logLocalStats(sequential,
                                 fitness,
                                 [misc_util:result(I) || I <- Islands]),
            logger:logLocalStats(sequential,
                                 population,
                                 [length(I) || I <- Islands]),
            logger:logGlobalStats(sequential,[{death,Counter#counter.death},
                                              {fight,Counter#counter.fight},
                                              {reproduction,Counter#counter.reproduction},
                                              {migration,Counter#counter.migration}]),
            %%             io_util:printSeq(Islands),
            timer:send_after(config:writeInterval(),write),
            loop(Islands,#counter{});
        theEnd ->
            lists:max([misc_util:result(I) || I <- Islands])
    after 0 ->
            {NrOfEmigrants,IslandsMigrated} = evolution:doMigrate(Islands),
            Environment = config:agent_env(),
            Groups = [misc_util:groupBy([{Environment:behaviour_function(Agent),Agent} || Agent <- I]) || I <- IslandsMigrated],
            NewGroups = [lists:map(fun evolution:sendToWork/1,I) || I <- Groups],
            NewIslands = [misc_util:shuffle(lists:flatten(I)) || I <- NewGroups],
            NewCounter = countAllIslands(Groups,Counter),
            loop(NewIslands,NewCounter#counter{migration = NrOfEmigrants + Counter#counter.migration})
    end.

%% @doc Liczy kategorie (ile fights,deaths etc.) na wszystkich wyspach i dodaje do Counter.
-spec countAllIslands([list()],counter()) -> counter().
countAllIslands(GroupedIslands,Counter) ->
    CountedIslands = [misc_util:countGroups(I,#counter{}) || I <- GroupedIslands],
    lists:foldl(fun misc_util:addCounters/2,Counter,CountedIslands).
