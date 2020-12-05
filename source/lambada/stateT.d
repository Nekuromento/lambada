module lambada.stateT;

template StateT(MM) {
    import lambada.traits: isMonad;

    static if (isMonad!MM) {
        alias M = MM.Meta;
    } else {
        alias M = MM;
    }

    template _hoist(alias f) {
        template _hoist(T: Transformer!(L, R), L, R) {
            alias Return = ReturnType!(toFunctionType!(f, M.Constructor!R));
            alias MT = StateT!Return;
            MT!(L, Return.Meta.Parameter.Meta.Parameter) _hoist(T x) {
                import std.typecons: tuple;
                return typeof(return)((L s) => f(x.evaluate(s)).map!(y => tuple(y, s)));
            }
        }
    }

    Transformer!(S, S) _get(S)() {
        import std.typecons: tuple;
        return Transformer!(S, S)((S x) => M.of(tuple(x, x)));
    }

    template _put(T) {
        alias Empty = typeof(null);

        Transformer!(T, Empty) _put(T x) {
            import std.typecons: tuple;
            return typeof(return)((T _) => M.of(tuple(null, x)));
        }
    }

    template _modify(alias f) {
        alias Empty = typeof(null);

        import std.traits: ReturnType;
        Transformer!(ReturnType!f, Empty) _modify() {
            import std.typecons: tuple;
            return typeof(return)((ReturnType!f s) => M.of(tuple(null, f(s))));
        }
    }

    Transformer!(L, R) _fromState(T: State!(L, R), L, R)(T x) {
        return Transformer!(L, R)((L s) => M.of(x.run(s)));
    }

    template _fromM(L) {
        Transformer!(L, T.Meta.Parameter) _fromM(T)(T x) if (isMonad!T && is(M.Constructor!(T.Meta.Parameter) == T)) {
            import std.typecons: tuple;
            return Transformer!(L, T.Meta.Parameter)((L s) => x.map!(x => tuple(x, s)));
        }
    }
 
    struct Transformer(L, R) if (isMonad!(M.Constructor!R)) {
        struct Meta {
            alias Constructor(U) = Transformer!(L, U);
            alias Parameter = R;
            static Transformer!(L, B) of(B)(B x) {
                import std.typecons: tuple;
                return Transformer!(L, B)((L y) => M.of(tuple(x, y)));
            }
            alias get = _get!L;
            alias put = _put!L;
            alias modify = _modify;
            alias hoist = _hoist;
            alias fromState = _fromState;
            alias fromM = _fromM!L;
        }

        import std.typecons: Tuple;
        M.Constructor!(Tuple!(R, L)) delegate(L) _;

        import std.traits: isCallable, arity;
        this(F)(F f) if (isCallable!F && arity!F == 1) {
            import lambada.combinators: apply;
            alias x = apply!f;
            this._ = &x!L;
        }

        alias of = Meta.of;

        M.Constructor!(Tuple!(R, L)) run(L x) {
            return _(x);
        }
        alias opCall = run;

        M.Constructor!R evaluate(L x) {
            return run(x).map!(x => x[0]);
        }

        M.Constructor!L execute(L x) {
            return run(x).map!(x => x[1]);
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

                return Transformer!(L, U)((L x) {
                    auto result = _run(x);
                    return result.chain!(x => f(x[0]).run(x[1]));
                });
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

        import std.traits: arity, isCallable;
        static if (isCallable!R && arity!R == 1) {
            import std.traits: Parameters, ReturnType;

            Transformer!(L, ReturnType!R) ap(Transformer!(L, Parameters!R[0]) x) {
                return this.chain!(f => x.map!f);
            }
        }

        alias run this;
    }

    template transformer(L) {
        auto transformer(T)(T x) if (isMonad!T) {
            return Transformer!(L, T.Meta.Parameter.Meta.Parameter)(x);
        }
    }

    alias StateT = Transformer;
}

template StateTMeta(M, L) {
    alias T = StateT!M;
    alias StateTMeta = T!(L, typeof(null)).Meta;
}

