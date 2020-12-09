import std.stdio: writeln;
import std.file: readText;

import lambada.combinators: constant, compose;
import lambada.io: IO, IOMeta;
import lambada.stateT: StateTMeta;

enum readFile = (string file) =>
    IO!string(() => readText(file));

enum println = (string t) =>
    IO!(typeof(null))(() {
        writeln(t);
        return null;
    });

enum prependTo = (string a) =>
    (string b) => b ~ a;

void main() {
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
