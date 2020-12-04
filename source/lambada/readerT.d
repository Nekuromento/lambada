module lambada.readerT;

template ReaderT(MM) {
    import lambada.traits: isMonad;

    static if (isMonad!MM) {
        alias M = MM.Meta;
    } else {
        alias M = MM;
    }

    Transformer!(T, T) _ask(T)() if (isMonad!(M.Constructor!T)) {
        return Transformer!(T, T)(&M.of!T);
    }

    template _fromReader(F) {
        import std.traits: arity, isCallable;

        static if (isCallable!F && arity!F == 1) {
            import std.traits: Parameter, ReturnType;

            Transformer!(Parameter!F[0], ReturnType!F) fromReader(F f) {
                import lambada.combinators: compose;
                alias x = compose!(M.of, f);
                return typeof(return)(&x!(Parameter!F[0]));
            }
        }
    }

    struct Transformer(L, R) if (isMonad!(M.Constructor!R)) {
        struct Meta {
            alias Constructor(U) = Transformer!(L, U);
            alias Parameter = R;

            static Transformer!(L, U) of(U)(U x) {
                import lambada.combinators: compose, constant;
                alias f = compose!(M.of, constant!x);
                return Transformer!(L, U)(&f!L);
            }
            alias ask = _ask!L;
            alias fromReader = _fromReader;
        }

        M.Constructor!R delegate(L) _;

        alias of = Meta.of;

        import std.traits: arity, isCallable;
        this(F)(F f) if (isCallable!F && arity!F == 1) {
            import lambada.combinators: apply;
            alias x = apply!f;
            this._ = &x!L;
        }

        M.Constructor!R run(L x) {
            return _(x);
        }
        alias opCall = run;

        template local(F) if (isCallable!f && is(ReturnType!f == L)) {
            import std.traits: Parameters, ReturnType;

            Transformer!(Parameters!f[0], R) local(F f) {
                import lambada.combinators: compose;
                //XXX: hack to fix delegates referencing dead objects:
                //     capture local frame instead of this
                auto _run = this._;

                alias x = compose!(_run, f);
                return typeof(return)(&x!(Parameters!f[0]));
            }
        }

        template chain(alias f) {
            import std.traits: ReturnType;

            import lambada.traits: toFunctionType;

            alias Return = ReturnType!(toFunctionType!(f, R));
            template RightType(T : E!(D, U), alias E, D, U) if (is(T == Transformer!(D, U)) && is(D == L)) {
                alias RightType = U;
            }
            alias U = RightType!Return;

            Transformer!(L, U) chain() {
                //XXX: hack to fix delegates referencing dead objects:
                //     capture local frame instead of this
                auto _run = this._;

                return Transformer!(L, U)((L e) => _run(e).chain!(a => f(a).run(e)));
            }
        }

        template map(alias f) {
            import std.traits: ReturnType;

            import lambada.traits: toFunctionType;

            Transformer!(L, ReturnType!(toFunctionType!(f, R))) map() {
                import lambada.combinators: compose;
                return this.chain!(compose!(this.of, f));
            }
        }

        static if (isCallable!R && arity!R == 1) {
            import std.traits: Parameters, ReturnType;

            Transformer!(L, ReturnType!R) ap(Transformer!(L, Parameters!R[0]) x) {
                return this.chain!(f => x.map!f);
            }
        }
    }

    alias ReaderT = Transformer;
}

template ReaderTMeta(M, L) {
    alias T = ReaderT!M;
    alias ReaderTMeta = T!(L, typeof(null)).Meta;
}
