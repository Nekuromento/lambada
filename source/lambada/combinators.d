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
    auto flip(T)(T a) {
        return b => f(b)(a);
    }
}

auto identity(T)(T x) {
    return x;
}

// Y combinator
alias fix = f => {
    immutable g = h => x => f(h(h))(x);
    return g(g);
};
