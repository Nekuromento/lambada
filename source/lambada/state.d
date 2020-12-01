module lambada.state;

State!(S, S) get(S)() {
    import std.typecons: tuple;
    return State!(S, S)((S x) => tuple(x, x));
}

template put(T) {
    alias Empty = typeof(null);

    State!(T, Empty) put(T x) {
        import lambada.combinators: constant;
        alias fn = constant!x;
        return modify!(fn!T);
    }
}

template modify(alias f) {
    alias Empty = typeof(null);

    import std.traits: ReturnType;
    State!(ReturnType!f, Empty) modify() {
        import std.typecons: tuple;
        return typeof(return)((ReturnType!f s) => tuple(null, f(s)));
    }
}

struct State(S, A) {
    import std.traits: isCallable, arity;
    import std.typecons: Tuple;

    Tuple!(A, S) delegate(S) _;

    this(A x) {
        import std.typecons: tuple;
        this._ = y => tuple(x, y);
    }

    static State of(A x) {
        return State(x);
    }

    this(F)(F f) if (isCallable!F) {
        import lambada.combinators: apply;
        alias x = apply!f;
        this._ = &x!S;
    }

    Tuple!(A, S) run(S x) {
        return _(x);
    }

    A evaluate(S x) {
        return run(x)[0];
    }

    S execute(S x) {
        return run(x)[1];
    }

    static if (isCallable!A && arity!A == 1) {
        import std.traits: Parameters, ReturnType;
        State!(S, ReturnType!A) ap(State!(S, Parameters!A[0]) x) {
            return this.chain!(f => x.map!f);
        }
    }

    template map(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        State!(S, ReturnType!(toFunctionType!(f, A))) map() {
            import lambada.combinators: compose;
            return this.chain!(compose!(typeof(return), f));
        }
    }

    template chain(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        alias Return = ReturnType!(toFunctionType!(f, A));
        template RightType(R : E!(D, G), alias E, D, G) if (is(R == State!(D, G)) && is(S == D)) {
            alias RightType = G;
        }
        alias G = RightType!Return;

        State!(S, G) chain() {
            //XXX: hack to fix delegates referencing dead objects:
            //     capture local frame instead of this
            auto _run = this._;

            return State!(S, G)((S s) {
                auto result = _run(s);
                return f(result[0]).run(result[1]);
            });
        }
    }
}
