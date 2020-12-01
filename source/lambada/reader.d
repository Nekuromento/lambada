module lambada.reader;

Reader!(T, T) ask(T)() {
    import lambada.combinators: identity;
    return Reader!(T, T)(&identity!T);
}

struct Reader(T, U) {
    import std.traits: isCallable;

    U delegate(T) _;

    this(U x) {
        import lambada.combinators: constant;
        alias f = constant!x;
        this._ = &f!T;
    }

    static Reader of(U x) {
        return Reader(x);
    }

    this(F)(F f) if (isCallable!F) {
        import lambada.combinators: apply;
        alias x = apply!f;
        this._ = &x!T;
    }

    U run(T x) {
        return _(x);
    }

    template local(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        static if (isCallable!f) {
            Reader!(ReturnType!f, U) local() {
                import lambada.combinators: compose;
                //XXX: hack to fix delegates referencing dead objects:
                //     capture local frame instead of this
                auto _run = this._;

                return typeof(return)(compose!(_run, f));
            }
        } else {
            auto local(G)() {
                return this.local!(f!G);
            }
        }
    }

    import std.traits: arity;
    static if (isCallable!U && arity!U == 1) {
        import std.traits: Parameters, ReturnType;

        Reader!(T, ReturnType!U) ap(Reader!(T, Parameters!U[0]) x) {
            return this.chain!(f => x.map!f);
        }
    }

    template map(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        Reader!(T, ReturnType!(toFunctionType!(f, U))) map() {
            import lambada.combinators: compose;
            return this.chain!(compose!(typeof(return), f));
        }
    }

    template chain(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        alias Return = ReturnType!(toFunctionType!(f, U));
        template RightType(R : E!(D, G), alias E, D, G) if (is(R == Reader!(D, G)) && is(T == D)) {
            alias RightType = G;
        }
        alias G = RightType!Return;

        Reader!(T, G) chain() {
            //XXX: hack to fix delegates referencing dead objects:
            //     capture local frame instead of this
            auto _run = this._;

            return Reader!(T, G)((T x) => f(_run(x)).run(x));
        }
    }
}
