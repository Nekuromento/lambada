module FPToTheMax;

import std.conv: to;
import std.parallelism: task;
import std.stdio: readln, writeln;
import std.typecons: tuple;
import std.random: Random, uniform;
import std.string: strip, toLower;

import lambada.combinators: compose;
import lambada.io: IO;
import lambada.maybe: tryCatch;
import lambada.task: Task, TaskMeta, fromIO;
import lambada.apply: sequence;

enum println = (string t) =>
    IO!(typeof(null))({
        writeln(t);
        return null;
    });

auto rnd = Random(3);

alias T = TaskMeta;

// read from standard input
enum getStrLn = () =>
    Task!string(task!(() => readln().strip));

// write to standard output
alias putStrLn = compose!(fromIO, println);

// ask something and get the answer
enum ask = (string question) =>
    putStrLn(question).chain!(_ => getStrLn());

// get a random int between 1 and 5
enum random = () =>
    Task!int(task!(() => uniform!"[]"(1, 5, rnd)));

// parse a string to an integer
enum parse = (string s) =>
    tryCatch!(() => s.to!int);

//
// game
//

Task!bool shouldContinue(string name) {
    return ask("Do you want to continue, " ~ name ~ " (y/n)?").chain!((answer) {
        switch (answer.toLower) {
            case "y":
                return T.of(true);
            case "n":
                return T.of(false);
            default:
                return shouldContinue(name);
        }
    });
}

Task!(typeof(null)) gameLoop(string name) {
    // run `n` tasks in parallel
    return tuple(random(), ask("Dear " ~ name ~ ", please guess a number from 1 to 5"))
        .sequence()
        .chain!(result =>
            parse(result[1]).fold!(
                x =>
                    x == result[0]
                        ? putStrLn("You guessed right, " ~ name ~ "!")
                        : putStrLn("You guessed wrong, " ~ name ~ "! The number was: " ~ result[0].to!string),
                _ => putStrLn("You did not enter an integer!"),
            )
        )
        .chain!(_ => shouldContinue(name))
        .chain!(b => b ? gameLoop(name) : T.of(null));
}

void example() {
    auto program = ask("What is your name?")
        .chain!(name => putStrLn("Hello, " ~ name ~ " welcome to the game!").map!(_ => name))
        .chain!gameLoop
    ;

    program.fork();
}

version (Example_FPToTheMax) {
    void main() { example(); }
}
