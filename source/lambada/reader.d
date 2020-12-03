module lambada.reader;

Reader!(T, T) ask(T)() {
    import lambada.combinators: identity;
    return Reader!(T, T)(&identity!T);
}

struct Reader(T, U) {
    struct Meta {
        alias Constructor(V) = Reader!(T, V);
        alias Parameter = U;
        static Reader!(T, V) of(V)(V x) {
            import lambada.combinators: constant;
            alias f = constant!x;
            return Reader!(T, V)(&f!T);
        }
    }

    U delegate(T) _;

    alias of = Meta.of;

    import std.traits: isCallable;
    this(F)(F f) if (isCallable!F) {
        import lambada.combinators: apply;
        alias x = apply!f;
        this._ = &x!T;
    }

    U run(T x) {
        return _(x);
    }

    template local(alias f) {
        import std.traits: Parameters, ReturnType;

        import lambada.traits: toFunctionType;

        static if (isCallable!f && is(ReturnType!f == T)) {
            Reader!(Parameters!f[0], U) local() {
                import lambada.combinators: compose;
                //XXX: hack to fix delegates referencing dead objects:
                //     capture local frame instead of this
                auto _run = this._;
                alias x = compose!(_run, f);

                return typeof(return)(&x!(Parameters!f[0]));
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
            return this.chain!(compose!(this.of, f));
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

    static if (is(U: Reader!(D, G), D, G) && is(D == T)) {
        Reader!(T, G) flatten() {
            import lambada.combinators: identity;
            return this.chain!identity;
        }
    }
}
