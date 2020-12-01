module lambada.combinators;

import std.traits: ReturnType;

import lambada.traits: toFunctionType;

template apply(alias f) {
    auto apply(T...)(T x) {
        return f(x);
    }
}

template constant(alias x) {
    auto constant(T...)(T _) {
        return x;
    }
}

template compose(alias f, alias g) {
    auto compose(T...)(T x) {
        return f(g(x));
    }
}

template flip(alias f) {
    private struct Wrapper(alias a) {
        auto opCall(U)(U b) {
            return f(b)(a);
        }
    }

    private Wrapper!T wrap(T)(T a) {
        return Wrapper!a.init;
    }

    auto flip(T)(T a) {
        return wrap(a);
    }
}

auto identity(T)(T x) {
    return x;
}

// Y combinator
template fix(alias f) {
    auto fix(T)(T x) {
        alias g(alias h) = x => f(h!h)(x);
        return g!g;
    }
}
