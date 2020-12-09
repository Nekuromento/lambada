module lambada.state;

import std.traits: isCallable, ReturnType;

State!(S, S) get(S)() {
    import std.typecons: tuple;
    return State!(S, S)((S x) => tuple(x, x));
}

State!(T, typeof(null)) put(T)(T x) {
    import lambada.combinators: constant;
    alias fn = constant!x;
    return modify(&fn!T);
}

State!(ReturnType!(F.init), typeof(null)) modify(F)(F f) if (isCallable!f) {
    import std.typecons: tuple;
    return typeof(return)((ReturnType!f s) => tuple(null, f(s)));
}

struct State(S, A) {
    struct Meta {
        alias Constructor(T) = State!(S, T);
        alias Parameter = A;
        static State!(S, B) of(B)(B x) {
            import std.typecons: tuple;
            return State!(S, B)((S y) => tuple(x, y));
        }
        alias get = .get!S;
        alias put = .put!S;
        alias modify = .modify;
    }

    import std.typecons: Tuple;

    Tuple!(A, S) delegate(S) _;

    alias of = Meta.of;

    this(F)(F f) if (isCallable!f) {
        import lambada.combinators: apply;
        alias x = apply!f;
        this._ = &x!S;
    }

    Tuple!(A, S) run(S x) {
        return _(x);
    }
    alias opCall = run;

    A evaluate(S x) {
        return run(x)[0];
    }

    S execute(S x) {
        return run(x)[1];
    }

    import std.traits: arity;
    static if (isCallable!A && arity!A == 1) {
        import std.traits: Parameters;

        State!(S, ReturnType!A) ap(State!(S, Parameters!A[0]) x) {
            return this.chain!(f => x.map!f);
        }
    }

    template map(alias f) {
        import lambada.traits: toFunctionType;

        State!(S, ReturnType!(toFunctionType!(f, A))) map() {
            import lambada.combinators: compose;
            return this.chain!(compose!(this.of, f));
        }
    }

    template chain(alias f) {
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

    static if (is(A: State!(D, G), D, G) && is(D == S)) {
        State!(S, G) flatten() {
            import lambada.combinators: identity;
            return this.chain!identity;
        }
    }
}

alias StateMeta(T) = State!(T, typeof(null)).Meta;
