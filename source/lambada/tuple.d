module lambada.tuple;

import std.algorithm: joiner, map;
import std.conv: to;
import std.meta: allSatisfy;
import std.range: iota, chain;
import std.typecons: tuple, Tuple;

import lambada.traits: isApplicative;

auto sequenceAll(Args...)(auto ref Tuple!Args self) if (allSatisfy!(isApplicative, Args)) {
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
