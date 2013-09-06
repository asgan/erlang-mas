%% @author jstypka <jasieek@student.agh.edu.pl>
%% @version 1.0

-module(misc_util).
-export([groupBy/2, shuffle/1, behavior/1, behavior_noMig/1, checkIfDead/1, clearInbox/0, result/1, index/2]).

%% ====================================================================
%% API functions
%% ====================================================================

%% @spec groupBy(function(),List1) -> List2
%% @doc Funkcja grupujaca agentow do krotek przy pomocy funkcji F.
%% Zwracana jest lista w formie [{migration,[A1,A2]},{fight,[A3,A4,A5]}]
groupBy(F, L) ->
  dict:to_list(
    lists:foldr(fun({K,V}, D) ->
      dict:append(K, V, D)
    end , dict:new(), [ {F(X), X} || X <- L ])).

%% @spec shuffle(List1) -> List2
%% @doc Funkcja mieszajaca podana liste.
shuffle(L) ->
  Rand = [{random:uniform(), N} || N <- L],
  [X||{_,X} <- lists:sort(Rand)].

%% @spec behavior(Agent) -> death | migration | reproduction | fight
%% @doc Funkcja przyporzadkowujaca agentowi dana klase, na podstawie
%% jego energii.
behavior({_,_,0}) ->
  death;
behavior({_, _, Energy}) ->
  case random:uniform() < config:migrationProbability() of
    true -> migration;
    false -> case Energy > config:reproductionThreshold() of
               true -> reproduction;
               false -> fight
             end
  end.

%% @spec behavior_noMig(Agent) -> death | reproduction | fight
%% @doc Funkcja przyporzadkowujaca agentowi dana klase, na podstawie
%% jego energii.
behavior_noMig({_,_,0}) ->
  death;
behavior_noMig({_, _, Energy}) ->
  case Energy > config:reproductionThreshold() of
    true -> reproduction;
    false -> fight
  end.

%% @spec checkIfDead(List1) -> ok
%% @doc Funkcja upewniajaca sie, ze wszystkie monitorowane procesy zostaly zakonczone
checkIfDead([]) ->
  ok;
checkIfDead(Pids) ->
  receive
    {'DOWN',_Ref,process,Pid,_Reason} ->
      checkIfDead(lists:delete(Pid,Pids))
  after 1000 ->
    io:format("Not all dead~n"),
    timeout
  end.

%% @spec clearInbox() -> ok
%% @doc Funkcja czyszczaca skrzynke.
clearInbox() ->
  receive
    _ -> clearInbox()
  after 0 ->
    ok
  end.

index(Elem,List) ->
  index(Elem,List,1).

%% @spec result(List1) -> float() | islandEmpty
%% @doc Funkcja okreslajaca najlepszy wynik na podstawie przeslanej listy agentow
result(Agents) ->
  case Agents of
    [] ->
      islandEmpty;
    _ ->
      lists:max([ Fitness || {_ ,Fitness, _} <- Agents])
  end.
%% ====================================================================
%% Internal functions
%% ====================================================================

index(Elem,[Elem|_],Inc) ->
  Inc;
index(_,[],_) ->
  notFound;
index(Elem,[_|T],Inc) ->
  index(Elem,T,Inc+1).

