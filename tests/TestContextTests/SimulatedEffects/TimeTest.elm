module TestContextTests.SimulatedEffects.TimeTest exposing (all)

import Expect
import Html
import SimulatedEffect.Process as Process
import SimulatedEffect.Task as Task
import Test exposing (..)
import TestContext exposing (SimulatedEffect, SimulatedTask, TestContext)
import TestingProgram exposing (Msg(..))


startTask : List (SimulatedTask x a) -> TestingProgram.TestContext
startTask initialTasks =
    TestingProgram.start (List.map (Task.attempt (Debug.toString >> Log)) initialTasks)


all : Test
all =
    describe "simulated time effects"
        [ test "simulates Process.sleep" <|
            \() ->
                startTask [ Process.sleep 700 ]
                    |> TestContext.advanceTime 700
                    |> TestContext.expectModel (Expect.equal [ "Ok ()" ])
        , test "sleep does not trigger until the delay has passed" <|
            \() ->
                startTask [ Process.sleep 700 ]
                    |> TestContext.advanceTime 699
                    |> TestContext.update (Log "*")
                    |> TestContext.advanceTime 1
                    |> TestContext.expectModel (Expect.equal [ "*", "Ok ()" ])
        , test "can chain multiple sleeps" <|
            \() ->
                startTask [ Process.sleep 250 |> Task.andThen (\() -> Process.sleep 25) ]
                    |> TestContext.advanceTime 274
                    |> TestContext.update (Log "*")
                    |> TestContext.advanceTime 1
                    |> TestContext.expectModel (Expect.equal [ "*", "Ok ()" ])
        , test "resolves sleeps in chronological order" <|
            \() ->
                startTask
                    [ Task.map (\() -> 10) (Process.sleep 10)
                    , Task.map (\() -> 900) (Process.sleep 900)
                    , Task.map (\() -> 33) (Process.sleep 33)
                    ]
                    |> TestContext.advanceTime 1000
                    |> TestContext.expectModel (Expect.equal [ "Ok 10", "Ok 33", "Ok 900" ])
        , test "non-future events are immediately triggered" <|
            \() ->
                startTask [ Process.sleep 0 ]
                    |> TestContext.expectModel (Expect.equal [ "Ok ()" ])
        , test "sleeps queued after time has advanced are queued at the correct time" <|
            \() ->
                startTask []
                    |> TestContext.advanceTime 100
                    |> TestContext.update (Log "A")
                    |> TestContext.update (ProduceEffects [ Task.attempt (Debug.toString >> Log) <| Process.sleep 10 ])
                    |> TestContext.advanceTime 9
                    |> TestContext.update (Log "B")
                    |> TestContext.advanceTime 1
                    |> TestContext.expectModel (Expect.equal [ "A", "B", "Ok ()" ])
        ]
