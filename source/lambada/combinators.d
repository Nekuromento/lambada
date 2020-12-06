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

template compose(alias f, alias g, alias h) {
    auto compose(T...)(T x) {
        return f(g(h(x)));
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

template fix(F) {
    import std.traits: isCallable, arity, ReturnType, Parameters;

    static assert(isCallable!F && arity!F == 1);
    static assert(is(ReturnType!F == Parameters!F[0]));
    alias Self = ReturnType!F;

    struct W {
        Self delegate(Self) f;

        Self run(W w) {
            return f((Parameters!Self x) => w.run(w)(x));
        }
    }

    Self fix(F f) {
        import lambada.combinators: apply;
        alias x = apply!f;
        auto w = W(&x!Self);
        return w.run(w);
    }
}
