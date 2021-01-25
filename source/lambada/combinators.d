module lambada.combinators;

public {
    import std.functional: compose, pipe, flip = reverseArgs;
}

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

template substitution(alias f, alias g) {
    auto substitution(T...)(T x) {
        return f(x)(g(x));
    }
}

template psy(alias f, alias g) {
    struct Y(T) {
        T x;
        auto opCall(T...)(T y) {
            return f(g(x))(g(y));
        }
    }
    struct X {
        auto opCall(T...)(T x) {
            Y!T y;
            y.x = x;
            return y;
        }
    }
    auto psy() {
        return X.init;
    }
}

template thrush(alias x) {
    import std.traits: isCallable;
    auto thrush(F)(F f) if (isCallable!f) {
        return f(x);
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
