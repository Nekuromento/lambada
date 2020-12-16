module lambada.apply;

import std.meta: allSatisfy;
import std.typecons: Tuple;

import lambada.traits: isApplicative;

auto sequence(Args...)(auto ref Tuple!Args self) if (allSatisfy!(isApplicative, Args)) {
    import std.algorithm: joiner, map;
    import std.conv: to;
    import std.range: iota, chain;
    import std.typecons: tuple;

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
