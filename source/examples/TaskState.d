import core.thread: Thread;

import std.conv: to;
import std.datetime: dur;
import std.parallelism: task;
import std.stdio: writeln;

import lambada.combinators: constant, compose;
import lambada.io: IO;
import lambada.task: Task, TaskMeta, fromIO;
import lambada.stateT: StateTMeta;

enum println = (string t) =>
    IO!(typeof(null))({
        writeln(t);
        return null;
    });

enum prependTo = (string a) =>
    (string b) => b ~ a;

enum question = () =>
    TaskMeta.of("What is the answer to Life, the Universe and Everything?\n");

enum deepThought = () {
    auto t = task!({
        enum sevenAndAHalfMillionYears = 7500000;
        // I suggest we work in milliseconds, as I don't think waiting for
        // seven and a half million years is really just for such example.
        Thread.sleep(dur!("msecs")(sevenAndAHalfMillionYears / 10000));
        return 42;
    });
    return Task!int(t);
};

void example() {
    // Monad which contains state and can do Promise.
    alias M = StateTMeta!(TaskMeta, string);

    // Ask Deep Thought for the ultimate question of Life, the Universe and Everything.
    auto program = M.fromM(question())
        .chain!(compose!(M.modify, prependTo))
        .chain!(_ => M.fromM(deepThought()))
        .map!(x => x.to!string)
        .chain!(compose!(M.modify, prependTo))
        .chain!(constant!(M.get))
        .chain!(compose!(M.fromM, fromIO, println))
    ;

    program.execute(">").fork();
}

version(Example_TaskState) {
    void main() { example(); }
}
