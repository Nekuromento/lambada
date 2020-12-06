module lambada.writer;

template tell(T) {
    alias Empty = typeof(null);

    Writer!(T, Empty) tell(T x) {
        import std.typecons: tuple;
        return Writer!(T, Empty)(() => tuple(null, x));
    }
}

import std.traits: arity, isCallable, ReturnType;
import std.typecons: Tuple;

//XXX: defined as non-member function to avoid infinite recursive instantiation
//     of writer instances with nesting tuples
auto listen(F)(F f) if (isCallable!F &&
                        arity!F == 0 &&
                        is(ReturnType!F: Tuple!(L, R), L, R)) {
    template RightType(R : Tuple!(D, G), D, G) {
        alias RightType = G;
    }
    alias R = RightType!(ReturnType!F);

    return Writer!(R, ReturnType!F)(() {
        import std.typecons: tuple;
        auto result = f();
        return tuple(result, result[1]);
    });
}

struct Writer(W, A) {
    import lambada.traits: isMonoid;

    struct Meta {
        alias Constructor(T) = Writer!(W, T);
        alias Parameter = A;
        static if (isMonoid!W) {
            static Writer!(W, B) of(B)(B x) {
                import std.typecons: tuple;
                return Writer!(W, B)(() => tuple(x, W.empty()));
            }
        }
    }

    import std.typecons: Tuple;

    Tuple!(A, W) delegate() _;

    static if (isMonoid!W) {
        alias of = Meta.of;
    }

    this(F)(F f) if (isCallable!F && arity!F == 0) {
        import lambada.combinators: apply;
        alias x = apply!f;
        this._ = &x!();
    }

    Tuple!(A, W) run() {
        return _();
    }
    alias opCall = run;

    A evaluate() {
        return run()[0];
    }

    W execute() {
        return run()[1];
    }

    static if (isMonoid!W && isCallable!A && arity!A == 1) {
        import std.traits: Parameters;

        Writer!(W, ReturnType!A) ap(Writer!(W, Parameters!A[0]) x) {
            return this.chain!(f => x.map!f);
        }
    }

    template listens(alias f) {
        import lambada.traits: toFunctionType;

        Writer!(W, Tuple!(A, ReturnType!(toFunctionType!(f, W)))) listens() {
            //XXX: hack to fix delegates referencing dead objects:
            //     capture local frame instead of this
            auto _run = this._;

            return typeof(return)(() {
                import std.typecons: tuple;
                auto result = _run();
                return tuple(tuple(result[0], f(result[1])), result[1]);
            });
        }
    }

    template censor(alias f) {
        Writer censor() {
            //XXX: hack to fix delegates referencing dead objects:
            //     capture local frame instead of this
            auto _run = this._;

            return Writer(() {
                import std.typecons: tuple;
                auto result = _run();
                return tuple(result[0], f(result[1]));
            });
        }
    }

    static if (is(A: Tuple!(B, F), B, F) && isCallable!F && arity!F == 1) {
        import std.traits: Parameters;

        static if (is(ReturnType!F == W) && is(Parameters!F[0] == W)) {
            Writer!(W, B) pass() {
                //XXX: hack to fix delegates referencing dead objects:
                //     capture local frame instead of this
                auto _run = this._;

                return Writer!(W, B)(() {
                    import std.typecons: tuple;
                    auto result = _run();
                    return tuple(result[0][0], result[0][1](result[1]));
                });
            }
        }
    }

    template map(alias f) {
        import lambada.traits: toFunctionType;

        Writer!(W, ReturnType!(toFunctionType!(f, A))) map() {
            //XXX: hack to fix delegates referencing dead objects:
            //     capture local frame instead of this
            auto _run = this._;

            return typeof(return)(() {
                import std.typecons: tuple;
                auto result = _run();
                return tuple(f(result[0]), result[1]);
            });
        }
    }

    template chain(alias f) if (isMonoid!W) {
        import lambada.traits: toFunctionType;

        alias Return = ReturnType!(toFunctionType!(f, A));
        template RightType(R : E!(D, G), alias E, D, G) if (is(R == Writer!(D, G)) && is(W == D)) {
            alias RightType = G;
        }
        alias G = RightType!Return;

        Writer!(W, G) chain() {
            //XXX: hack to fix delegates referencing dead objects:
            //     capture local frame instead of this
            auto _run = this._;

            return Writer!(W, G)(() {
                import std.typecons: tuple;
                auto result = _run();
                auto t = f(result[0]).run();
                return tuple(t[0], result[1] ~ t[1]);
            });
        }
    }

    static if (is(A: Writer!(D, G), D, G) && is(D == W)) {
        Writer!(W, G) flatten() {
            import lambada.combinators: identity;
            return this.chain!identity;
        }
    }
}

alias WriterMeta(T) = Writer!(T, typeof(null)).Meta;
