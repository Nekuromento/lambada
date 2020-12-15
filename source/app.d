import core.thread: Thread;

import std.conv: to;
import std.datetime: dur;
import std.file: readText;
import std.parallelism: task;
import std.stdio: readln, write, writeln;
import std.algorithm: joiner, sum, map, filter;
import std.range: iota, chain;
import std.typecons: tuple, Tuple;
import std.random: Random, uniform;
import std.string: strip, toLower;
import std.meta: allSatisfy;

import lambada.traits: isApplicative;
import lambada.combinators: identity, constant, compose;
import lambada.io: IO, IOMeta;
import lambada.maybe: tryCatch;
import lambada.task: Task, TaskMeta, fromIO;
import lambada.stateT: StateTMeta;

enum readFile = (string file) =>
    IO!string(() => readText(file));

enum println = (string t) =>
    IO!(typeof(null))({
        writeln(t);
        return null;
    });

enum prependTo = (string a) =>
    (string b) => b ~ a;

void IOState() {
    // Monad which contains state and can do IO.
    alias M = StateTMeta!(IOMeta, string);

    // Load 2 files, concatenate them to the start state and print the result.
    auto program = M.fromM(readFile("dub.json"))
        .chain!(compose!(M.modify, prependTo))
        .chain!(_ => M.fromM(readFile("LICENSE")))
        .chain!(compose!(M.modify, prependTo))
        .chain!(constant!(M.get))
        .chain!(compose!(M.fromM, println))
    ;

    program.execute("Contents:\n").unsafePerform();
}

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

void TaskState() {
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

enum size = 30;

alias Board = bool[][];

// Comonadic Game of Life logic
struct Pos {
    ulong x;
    ulong y;
}

struct Pointer {
    Board board;
    Pos pos;

    Pointer updatePos(Pos x) {
        return Pointer(board, x);
    }

    auto extract() {
        return board[pos.x][pos.y];
    }

    Pointer extend(alias f)() {
        Board board = this.board.dup;
        foreach(x; 0 .. board.length) {
            foreach(y; 0 .. board[x].length) {
                board[x][y] = f(Pointer(board, Pos(x, y)));
            }
        }
        return Pointer(board, pos);
    }
}

enum inBounds = (Pos pos) =>
    pos.x >= 0 && pos.y >= 0 && pos.x < size && pos.y < size;

enum pointerNeighbours = (Pointer pointer) {
    auto offsets = [Pos(-1, -1), Pos(-1, 0), Pos(-1, 1), Pos(0, -1), Pos(0, 1), Pos(1, -1), Pos(1, 0), Pos(1, 1)];
    auto positions = offsets
        .map!(offset => Pos(pointer.pos.x + offset.x, pointer.pos.y + offset.y))
        .filter!inBounds;

    return positions.map!(pos => pointer.updatePos(pos).extract());
};

enum liveNeighbours = (Pointer pointer) =>
    pointerNeighbours(pointer).filter!identity.sum;

enum rules = (Pointer pointer) {
    auto c = pointer.extract();
    auto n = liveNeighbours(pointer);

    return c && (n < 2 || n > 3) ? false : (c && n == 2) || n == 3 || c;
};

enum step = (Board board) => Pointer(board, Pos(0, 0)).extend!rules.board;

enum clearScreen = () =>
    IO!(typeof(null))({
        write("\033[2J\033[1;1H");
        return null;
    });

auto rnd = Random(3);

enum setup = clearScreen;

enum generateBoard = () =>
    IO!Board({
        Board board = new bool[][size];
        foreach(x; 0 .. board.length) {
            board[x] = new bool[size];
            foreach(y; 0 .. board[x].length) {
                board[x][y] = uniform(0.0f, 1.0f, rnd) > 0.85f;
            }
        }
        return board;
    });

enum drawBoard = (Board board) =>
    clearScreen().chain!(_ => IO!(typeof(null))({
        foreach(x; 0 .. board.length) {
            foreach(y; 0 .. board[x].length) {
                if (board[x][y]) {
                    write("[]");
                } else {
                    write("  ");
                }
            }
            write('\n');
        }
        return null;
    }));

enum sleep = () =>
    IO!(typeof(null))({
        Thread.sleep(dur!"msecs"(66));
        return null;
    });

IO!(typeof(null)) loop(Board board) {
    return drawBoard(board)
        .chain!(_ => sleep())
        .chain!(_ => board.step.loop)
    ;
}

void GameOfComonads() {
    auto program = setup().chain!(_ => generateBoard()).chain!loop;

    // Perform effects!
    program.unsafePerform();
}

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

auto sequence(Args...)(auto ref Tuple!Args self) if (allSatisfy!(isApplicative, Args)) {
    enum args = iota(Args.length)
        .map!(i => i.to!string)
        .map!(i => "(Args[" ~ i ~ "].Meta.Parameter _" ~ i ~ ") => ")
        .joiner;
    enum _body = "tuple(".chain(
        iota(Args.length)
            .map!(i => i.to!string)
            .map!(i => "_" ~ i)
            .joiner(",")
    ).chain(")");
    alias tupleConstructor = mixin(args.chain(_body).to!string);
    enum first = q{self[0].map!tupleConstructor};
    enum rest = iota(Args.length - 1)
        .map!(i => ".ap(self[" ~ (i + 1).to!string ~ "])")
        .joiner;

    return mixin(first.chain(rest).to!string);
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

void FPToTheMax() {
    auto program = ask("What is your name?")
        .chain!(name => putStrLn("Hello, " ~ name ~ " welcome to the game!").map!(_ => name))
        .chain!gameLoop
    ;

    program.fork();
}

void main() {
    // IOState();
    // TaskState();
    // GameOfComonads();
    FPToTheMax();
}
