module lambada.writerT;

import std.traits: arity, isCallable, ReturnType;
import std.typecons: Tuple;

import lambada.traits: isMonad;

//XXX: defined as non-member function to avoid infinite recursive instantiation
//     of writer instances with nesting tuples
auto listen(F)(F f) if (isCallable!F &&
                        arity!F == 0 &&
                        isMonad!(ReturnType!F) &&
                        is(ReturnType!F.Meta.Parameter: Tuple!(L, R), L, R)) {
    template RightType(R : Tuple!(D, G), D, G) {
        alias RightType = G;
    }
    alias R = RightType!(ReturnType!F.Meta.Parameter);
    alias MT = WriterT!(ReturnType!F);

    import std.typecons: tuple;
    return MT!(R, ReturnType!F.Meta.Parameter)(() => f().map!(x => tuple(x, x[1])));
}

template WriterT(MM) {

    static if (isMonad!MM) {
        alias M = MM.Meta;
    } else {
        alias M = MM;
    }

    template _hoist(alias f) {
        import lambada.traits: toFunctionType;

        template _hoist(F) if (isCallable!F &&
                               arity!F == 0 &&
                               isMonad!(ReturnType!F) &&
                               is(M.Constructor!(ReturnType!F.Meta.Parameter) == ReturnType!F) &&
                               is(ReturnType!F.Meta.Parameter: T!(L, R), alias T, L, R) &&
                               is(Tuple!(L, R) == T)) {
            alias Return = ReturnType!(toFunctionType!(f, ReturnType!F));
            alias MT = WriterT!Return;

            MT!(L, R) _hoist(F x) {
                return typeof(return)(() => f(x()));
            }
        }
    }

    template _tell(T) {
        alias Empty = typeof(null);

        Writer!(T, Empty) _tell(T x) {
            import std.typecons: tuple;
            return Writer!(T, Empty)(() => M.of(tuple(null, x)));
        }
    }

    struct Transformer(L, R) if (isMonad!(M.Constructor!R)) {
        import lambada.traits: isMonoid;

        struct Meta {
            alias Constructor(U) = Transformer!(L, U);
            alias Parameter = R;
            static if (isMonoid!L) {
                static Transformer!(L, U) of(U)(U x) {
                    import std.typecons: tuple;
                    return Transformer!(L, U)(() => M.of(tuple(x, L.empty())));
                }
            }
            alias hoist = _hoist;
            alias tell = _tell;
        }

        import std.typecons: Tuple;

        M.Constructor!(Tuple!(R, L)) delegate() _;

        static if (isMonoid!L) {
            alias of = Meta.of;
        }

        this(F)(F f) if (isCallable!F && arity!F == 0) {
            import lambada.combinators: apply;
            alias x = apply!f;
            this._ = &x!();
        }

        M.Constructor!(Tuple!(R, L)) run() {
            return _();
        }
        alias opCall = run;

        M.Constructor!R evaluate() {
            return run().map!(x => x[0]);
        }

        M.Constructor!L execute() {
            return run().map!(x => x[1]);
        }

        template listens(alias f) {
            import lambada.traits: toFunctionType;

            Transformer!(L, Tuple!(R, ReturnType!(toFunctionType!(f, L)))) listens() {
                //XXX: hack to fix delegates referencing dead objects:
                //     capture local frame instead of this
                auto _run = this._;

                import std.typecons: tuple;
                return typeof(return)(() => _run().map!(x => tuple(tuple(x[0], f(x[1])), x[1])));
            }
        }

        template censor(alias f) {
            Transformer censor() {
                //XXX: hack to fix delegates referencing dead objects:
                //     capture local frame instead of this
                auto _run = this._;

                import std.typecons: tuple;
                return Transformer(() => _run().map!(x => tuple(x[0], f(x[1]))));
            }
        }

        template chain(alias f) if (isMonoid!L) {
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

                import std.typecons: tuple;
                return Transformer!(L, U)(
                    () => _run().chain!(
                        x => f(x[0]).run().map!(
                            y => tuple(y[0], x[1] ~ y[1])
                        )
                    )
                );
            }
        }

        template map(alias f) {
            import lambada.traits: toFunctionType;

            Transformer!(L, ReturnType!(toFunctionType!(f, R))) map() {
                //XXX: hack to fix delegates referencing dead objects:
                //     capture local frame instead of this
                auto _run = this._;

                import std.typecons: tuple;
                return typeof(return)(() => _run().map!(x => tuple(f(x[0]), x[1])));
            }
        }

        static if (isMonoid!L && isCallable!R && arity!R == 1) {
            import std.traits: Parameters;

            Transformer!(L, ReturnType!R) ap(Transformer!(L, Parameters!R[0]) x) {
                return this.chain!(f => x.map!f);
            }
        }
    }

    alias WriterT = Transformer;
}

template WriterTMeta(M, L) {
    alias T = WriterT!M;
    alias WriterTMeta = T!(L, typeof(null)).Meta;
}
