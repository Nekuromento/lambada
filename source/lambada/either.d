module lambada.either;

private struct Left(T) { T _; }
private struct Right(T) { T _; }

template left(R) {
    Either!(L, R) left(L)(L x) {
        return Either!(L, R)(Left!L(x));
    }
}

template right(L) {
    Either!(L, R) right(R)(R x) {
        return Either!(L, R)(Right!R(x));
    }
}

template tryCatch(alias f, alias g) {
    import std.meta: AliasSeq;
    import std.traits: ReturnType;

    import lambada.traits: toFunctionType;

    alias Empty = AliasSeq!();

    alias l = ReturnType!(toFunctionType!(f, Empty));
    alias r = ReturnType!(toFunctionType!(g, Exception));

    Either!(l, r) tryCatch() {
        try {
            return right!l(f());
        } catch (Exception e) {
            return left!r(g(e));
        }
    }
}

struct Either(L, R) {
    import lambada.traits: isMonoid;

    struct Meta {
        alias Constructor(T) = Either!(L, T);
        alias Parameter = R;
        alias of = right;
        static if (isMonoid!L) {
            enum empty = left(L.empty());
        }
        alias left = .left!R;
        alias right = .right!L;
    }

    import sumtype: SumType;

    SumType!(Left!L, Right!R) _;

    alias of = Meta.of;
    static if (isMonoid!L) {
        enum empty = Meta.empty;
    }

    this(Left!L _) {
        this._ = _;
    }

    this(Right!R _) {
        this._ = _;
    }

    bool isLeft() {
        import lambada.combinators: constant;
        return this.fold!(constant!true, constant!false);
    }

    bool isRight() {
        return !isLeft();
    }

    import lambada.maybe: Maybe;
    Maybe!L getLeft() {
        import lambada.maybe: just, none;
        import lambada.combinators: constant;
        return this.fold!(just, constant!(Maybe!L(none)));
    }

    Maybe!R getRight() {
        import lambada.maybe: just, none;
        import lambada.combinators: constant;
        return this.fold!(constant!(Maybe!R(none)), just);
    }

    alias toMaybe = getRight;

    Either!(R, L) swap() {
        return this.fold!(right!R, left!L);
    }

    R getOrElse(R x) {
        import lambada.combinators: identity, constant;
        return this.fold!(constant!x, identity);
    }

    Either orElse(Either x) {
        import lambada.combinators: constant;
        return this.fold!(constant!x, right!L);
    }

    import std.traits: arity, isCallable;
    static if (isCallable!R && arity!R == 1) {
        import std.traits: Parameters, ReturnType;

        Either!(L, ReturnType!R) ap(Either!(L, Parameters!R[0]) x) {
            return this.chain!(f => x.map!f);
        }
    }

    import lambada.traits: isSetoid;
    static if (isSetoid!L && isSetoid!R) {
        bool opEquals(Either x) {
            import lambada.combinators: constant;
            return this.fold!(
                a => x.fold!(b => a == b, constant!false),
                a => x.fold!(constant!false, b => a == b)
            );
        }
    } else static if (isSetoid!L && !isSetoid!R) {
        bool opEquals(Either x) {
            import lambada.combinators: constant;
            return this.fold!(
                a => x.fold!(b => a == b, constant!false),
                a => x.fold!(constant!false, constant!false)
            );
        }
    } else static if (!isSetoid!L && isSetoid!R) {
        bool opEquals(Either x) {
            import lambada.combinators: constant;
            return this.fold!(
                a => x.fold!(constant!false, constant!false),
                a => x.fold!(constant!false, b => a == b)
            );
        }
    }
    static if (isSetoid!L || isSetoid!R) {
        bool equals(Either x) {
            return this == x;
        }
    }

    import lambada.traits: isOrd;
    static if (isOrd!L && isOrd!R) {
        int opCmp(Either x) {
            import lambada.combinators: constant;
            return this.fold!(
                a => x.fold!(
                    b => a == b ? 0 : (a < b ? -1 : 1),
                    constant!(-1)
                ),
                a => x.fold!(
                    constant!1,
                    b => a == b ? 0 : (a < b ? -1 : 1)
                )
            );
        }
    } else static if (!isOrd!L && isOrd!R) {
        int opCmp(Either x) {
            import lambada.combinators: constant;
            return this.fold!(
                constant!(-1),
                a => x.fold!(
                    constant!1,
                    b => a == b ? 0 : (a < b ? -1 : 1)
                )
            );
        }
    } else static if (isOrd!L && !isOrd!R) {
        int opCmp(Either x) {
            import lambada.combinators: constant;
            return this.fold!(
                a => x.fold!(
                    b => a == b ? 0 : (a < b ? -1 : 1),
                    constant!(-1)
                ),
                constant!(-1)
            );
        }
    }
    static if (isOrd!L || isOrd!R) {
        int compare(Either x) {
            return this == x ? 0 : (this < x ? -1 : 1);
        }
    }

    import lambada.traits: isSemigroup;
    static if (isSemigroup!R) {
        Either opBinary(string op)(Either x) if (op == "~") {
            return this.fold!(left!R, a => x.chain!(b => right!L(a ~ b)));
        }

        Either concat(Either x) {
            return this ~ x;
        }
    }

    import lambada.validation: Validation;
    Validation!(L, R) toValidation() {
        import lambada.validation: success, failure;
        return this.fold!(failure!R, success!L);
    }

    U reduce(alias f, U)(U b) {
        import lambada.combinators: constant;
        return this.fold!(a => f(b, a), constant!b);
    }

    U reduceRight(alias f, U)(U b) {
        import lambada.combinators: constant;
        return this.fold!(a => f(a, b), constant!b);
    }

    static if (isMonoid!L) {
        Either filter(alias f)() {
            return this.fold!(identity, x => f(x) ? right(x) : empty);
        }
    }

    auto bimap(alias f, alias g)() {
        import std.traits: ReturnType;

        import lambada.combinators: compose;
        import lambada.traits: toFunctionType;

        alias l = toFunctionType!(f, L);
        alias r = toFunctionType!(g, R);
        alias onLeft = compose!(left!(ReturnType!r), f);
        alias onRight = compose!(right!(ReturnType!l), g);

        return this.fold!(onLeft, onRight);
    }

    template map(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        Either!(L, ReturnType!(toFunctionType!(f, R))) map() {
            import lambada.combinators: identity;
            return this.bimap!(identity, f);
        }
    }

    template chain(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        alias Return = ReturnType!(toFunctionType!(f, R));
        template RightType(T : E!(D, G), alias E, D, G) if (is(T == Either!(D, G)) && is(D == L)) {
            alias RightType = G;
        }
        alias G = RightType!Return;

        Either!(L, G) chain() {
            return this.fold!(left!G, f);
        }
    }

    static if (is(R: Either!(D, G), D, G) && is(D == L)) {
        Either!(L, G) flatten() {
            import lambada.combinators: identity;
            return this.chain!identity;
        }
    }

    auto fold(alias f, alias g)() {
        import sumtype: match;
        return this._.match!(
            (Left!L x) => f(x._),
            (Right!R x) => g(x._),
        );
    }

    import lambada.traits: isApplicative;
    static if (isApplicative!R) {
        R.Meta.Constructor!(Either!(L, R.Meta.Parameter)) sequence() {
            import lambada.combinators: identity;
            return this.traverse!identity;
        }
    }

    template traverse(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        alias Return = ReturnType!(toFunctionType!(f, R));

        static if (isApplicative!Return) {
            Return.Meta.Constructor!(Either!(L, Return.Meta.Parameter)) traverse() {
                import lambada.combinators: compose;
                return this.fold!(
                    compose!(Return.Meta.of, left!(Return.Meta.Parameter)),
                    x => f(x).map!(right!L)
                );
            }
        }
    }

    alias _ this;
}

alias EitherMeta(L) = Either!(L, typeof(null)).Meta;
