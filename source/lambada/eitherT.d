module lambada.eitherT;

template rightM(U) {
    import lambada.traits: isMonad;

    template rightM(T) if (isMonad!T) {
        alias TT = EitherT!T;

        TT!(U, T.Meta.Parameter) rightM(T x) {
            import lambada.either: right;
            return x.map!(right!U);
        }
    }
}

template leftM(V) {
    import lambada.traits: isMonad;

    template leftM(T) if (isMonad!T) {
        alias TT = EitherT!T;

        TT!(T.Meta.Parameter, V) leftM(T x) {
            import lambada.either: left;
            return x.map!(left!V);
        }
    }
}

template EitherT(MM) {
    import lambada.traits: isMonad;

    static if (isMonad!MM) {
        alias M = MM.Meta;
    } else {
        alias M = MM;
    }

    template _left(V) {
        Transformer!(U, V) _left(U)(U x) {
            import lambada.either: left;
            return transformer!U(M.of(left!V(x)));
        }
    }

    template _right(U) {
        import lambada.either: right;
        import lambada.combinators: compose;
        alias _right = compose!(transformer!U, M.of, right!U);
    }

    struct Transformer(L, R) if (isMonad!(M.Constructor!R)) {
        struct Meta {
            alias Constructor(U) = Transformer!(L, U);
            alias Parameter = R;

            alias of = right;
            alias right = _right!L;
            alias rightM = .rightM!L;
            alias left = _left!R;
            alias leftM = .leftM!R;
        }

        import lambada.either: Either;
        M.Constructor!(Either!(L, R)) run;

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

        Transformer!(R, L) swap() {
            return transformer!R(this.run.map!(e => e.swap()));
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
                import lambada.either: left;
                import lambada.combinators: compose;

                return transformer!L(this.run.chain!(
                    x => x.fold!(
                        compose!(M.of, left!U),
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
                import lambada.either: left, right;
                import lambada.combinators: compose;

                alias onLeft = compose!(M.of, left!(ReturnType!r), f);
                alias onRight = compose!(M.of, right!(ReturnType!l), g);

                return this.fold!(onLeft, onRight);
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

    alias EitherT = Transformer;
}

template EitherTMeta(M, L) {
    alias T = EitherT!M;
    alias EitherTMeta = T!(L, typeof(null)).Meta;
}

