module lambada.traits;

enum hasConcat(T) = __traits(compiles, (T a, T b) => a.concat(b)) &&
                    is(typeof(((T* a, T* b) => (*a).concat(*b))(null, null)) == T);

template toFunctionType(alias f, T) {
    import std.traits: isSomeFunction;

    static if (isSomeFunction!f) {
        alias toFunctionType = f;
    } else {
        alias toFunctionType = f!T;
    }
}
