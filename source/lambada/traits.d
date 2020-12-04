module lambada.traits;

//TODO: make more strict
enum hasMap(T) = __traits(compiles, T.init.map!(_ => 0));

enum isFunctor(T) = hasMap!T;

//TODO: make more strict
enum hasAp(T) = __traits(hasMember, T.of((int x) => x), "ap");

enum isApply(T) = isFunctor!T && hasAp!T;

//TODO: make more strict
enum hasOf(T) = __traits(compiles, T.of(0));

enum isApplicative(T) = isApply!T && hasOf!T;

//TODO: make more strict
enum hasChain(T) = __traits(hasMember, T.init, "chain");

enum isMonad(T) = isApplicative!T && hasChain!T;

enum hasConcat(T) = __traits(compiles, T.init ~ T.init) &&
                    is(typeof(T.init ~ T.init) == T);

enum isSemigroup(T) = hasConcat!T;

enum hasEmpty(T) = __traits(compiles, T.empty()) &&
                   is(typeof(T.empty()) == T);

enum isMonoid(T) = isSemigroup!T && hasEmpty!T;

template toFunctionType(alias f, T) {
    import std.traits: isCallable;

    static if (isCallable!f) {
        alias toFunctionType = f;
    } else {
        alias toFunctionType = f!T;
    }
}
