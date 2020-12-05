module lambada.maybeT;

template MaybeT(MM) {
    import lambada.traits: isMonad;

    static if (isMonad!MM) {
        alias M = MM.Meta;
    } else {
        alias M = MM;
    }

    template _hoist(alias f) {
        template _hoist(T: Transformer!U, U) {
            import std.traits: ReturnType;

            import lambada.maybe: Maybe;
            import lambada.traits: toFunctionType;

            alias Return = ReturnType!(toFunctionType!(f, M.Constructor!(Maybe!U)));
            alias MT = MaybeT!Return;
            MT!(Return.Meta.Parameter) _hoist(T x) {
                return typeof(return)(f(x.run));
            }
        }
    }

    struct Transformer(T) if (isMonad!(M.Constructor!T)) {
        struct Meta {
            alias Constructor(U) = Transformer!U;
            alias Parameter = T;

            import lambada.combinators: compose;
            import lambada.maybe: just;
            alias of = compose!(transformer, M.of, just);
        }

        import lambada.maybe: Maybe;
        M.Constructor!(Maybe!T) run;

        alias of = Meta.of;

        auto fold(alias f, alias g)() {
            return transformer(this.run.chain!(x => M.of(x.fold!(f, g))));
        }

        Transformer ofElse(Transformer x) {
            return transformer(this.run.chain!(a => a.fold!(_ => M.of(a), _ => x.run)));
        }

        M.Constructor!T getOrElse(T x) {
            return this.run.chain!(o => M.of(o.getOrElse(x)));
        }

        template chain(alias f) {
            import std.traits: ReturnType;

            import lambada.traits: toFunctionType;

            alias Return = ReturnType!(toFunctionType!(f, T));
            template Type(R : E!D, alias E, D) if (is(R == Transformer!D)) {
                alias Type = D;
            }
            alias U = Type!Return;

            Transformer!U chain() {
                import lambada.maybe: Maybe, none;
                return transformer(this.run.chain!(
                    x => x.fold!(
                        x => f(x).run,
                        _ => M.of(Maybe!U(none))
                    )
                ));
            }
        }

        template map(alias f) {
            import std.traits: ReturnType;

            import lambada.traits: toFunctionType;

            Transformer!(ReturnType!(toFunctionType!(f, T))) map() {
                import lambada.combinators: compose;
                return this.chain!(compose!(this.of, f));
            }
        }

        import std.traits: arity, isCallable;
        static if (isCallable!T && arity!T == 1) {
            import std.traits: Parameters, ReturnType;

            Transformer!(ReturnType!T) ap(Transformer!(Parameters!T[0]) x) {
                return this.chain!(f => x.map!f);
            }
        }

        alias run this;
    }

    auto transformer(T)(T x) if (isMonad!T) {
        return Transformer!(T.Meta.Parameter.Meta.Parameter)(x);
    }

    alias MaybeT = Transformer;
}

template MaybeTMeta(M) {
    alias T = MaybeT!M;
    alias MaybeTMeta = T!(typeof(null)).Meta;
}
