module lambada.validationT;

template successM(U) {
    Transformer!(U, T.Meta.Parameter) successM(T)(T x) if (isMonad!T) {
        import lambada.validation: success;
        return x.map!(success!U);
    }
}

template failureM(V) {
    Transformer!(T.Meta.Parameter, V) failureM(T)(T x) if (isMonad!T) {
        import lambada.validation: failure;
        return x.map!(failure!V);
    }
}

template ValidationT(MM) {
    import lambada.traits: isMonad;
    import lambada.validation: failure, success;

    static if (isMonad!MM) {
        alias M = MM.Meta;
    } else {
        alias M = MM;
    }

    template _failure(V) {
        Transformer!(U, V) _failure(U)(U x) {
            return transformer!U(M.of(failure!V(x)));
        }
    }

    template _success(U) {
        import lambada.combinators: compose;
        alias _success = compose!(transformer!U, M.of, success!U);
    }

    struct Transformer(L, R) if (isMonad!(M.Constructor!R)) {
        struct Meta {
            alias Constructor(U) = Transformer!(L, U);
            alias Parameter = R;

            alias of = success;
            alias success = _success!L;
            alias successM = .successM!L;
            alias failure = _failure!R;
            alias failureM = .failureM!R;
        }

        import lambada.validation: Validation;
        M.Constructor!(Validation!(L, R)) run;

        alias of = Meta.of;

        auto fold(alias f, alias g)() {
            return this.run.chain!(x => M.of(x.fold!(f, g)));
        }

        Transformer ofElse(Transformer x) {
            return transformer!L(this.run.chain!(a => a.fold!(_ => x.run, _ => M.of(a))));
        }

        M.Constructor!R getOrElse(R x) {
            return this.run.map!(e => e.getOrElse(x));
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
                import lambada.validation: failure;
                import lambada.combinators: compose;

                return transformer!L(this.run.chain!(
                    x => x.fold!(
                        compose!(M.of, failure!U),
                        r => f(r).run,
                    )
                ));
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

        template bimap(alias f, alias g) {
            import std.traits: ReturnType;

            import lambada.traits: toFunctionType;

            alias l = toFunctionType!(f, L);
            alias r = toFunctionType!(g, R);

            Transformer!(ReturnType!l, ReturnType!r) bimap() {
                import lambada.validation: success, failure;
                import lambada.combinators: compose;

                alias onLeft = compose!(M.of, failure!(ReturnType!r), f);
                alias onRight = compose!(M.of, success!(ReturnType!l), g);

                return this.fold!(onLeft, onRight);
            }
        }

        import std.traits: arity, isCallable;

        import lambada.traits: isSemigroup;

        static if (isCallable!R && arity!R == 1 && isSemigroup!L) {
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

    alias ValidationT = Transformer;
}

template ValidationTMeta(M, L) {
    alias T = ValidationT!M;
    alias ValidationTMeta = T!(L, typeof(null)).Meta;
}

