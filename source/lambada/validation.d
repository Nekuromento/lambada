module lambada.validation;

private struct Success(T) { T _; }
private struct Failure(T) { T _; }

template success(L) {
    Validation!(L, R) success(R)(R x) {
        return Validation!(L, R)(Success!R(x));
    }
}

template failure(R) {
    Validation!(L, R) failure(L)(L x) {
        return Validation!(L, R)(Failure!L(x));
    }
}

struct Validation(L, R) {
    struct Meta {
        alias Constructor(T) = Validation!(L, T);
        alias Parameter = R;
        alias of = success;
        alias success = .success!L;
        alias failure = .failure!R;
    }

    import sumtype: SumType;

    SumType!(Failure!L, Success!R) _;

    alias of = Meta.of;

    this(Success!R _) {
        this._ = _;
    }

    this(Failure!L _) {
        this._ = _;
    }

    bool isSuccess() {
        import lambada.combinators: constant;
        return this.fold!(constant!false, constant!true);
    }

    bool isFailure() {
        return !isSuccess();
    }

    R getOrElse(R x) {
        import lambada.combinators: identity, constant;
        return this.fold!(constant!x, identity);
    }

    Validation orElse(Validation x) {
        import lambada.combinators: constant;
        return this.fold!(constant!x, success!L);
    }

    import std.traits: arity, isCallable;

    import lambada.traits: isSemigroup;

    static if (isCallable!R && arity!R == 1 && isSemigroup!L) {
        import std.traits: Parameters, ReturnType;

        Validation!(L, ReturnType!R) ap(Validation!(L, Parameters!R[0]) x) {
            return this.fold!(
                    a => x.fold!(
                        b => failure!(ReturnType!R)(a ~ b),
                        _ => failure!(ReturnType!R)(a)
                    ),
                    f => x.map!f
            );
        }
    }

    static if (isSemigroup!L && isSemigroup!R) {
        Validation opBinary(string op)(Validation x) if (op == "~") {
            import lambada.combinators: identity;
            return this.fold!(
                a => x.bimap!(b => a ~ b, identity),
                a => x.map!(b => a ~ b)
            );
        }

        Validation concat(Validation x) {
            return this ~ x;
        }
    }

    import lambada.maybe: Maybe;
    Maybe!L getFailure() {
        import lambada.maybe: just, none;
        import lambada.combinators: constant;
        return this.fold!(just, constant!(Maybe!L(none)));
    }

    Maybe!R getSuccess() {
        import lambada.maybe: just, none;
        import lambada.combinators: constant;
        return this.fold!(constant!(Maybe!R(none)), just);
    }

    alias toMaybe = getSuccess;

    import lambada.either: Either;
    Either!(L, R) toEither() {
        import lambada.either: left, right;
        return this.fold!(left!R, right!L);
    }

    auto bimap(alias f, alias g)() {
        import std.traits: ReturnType;

        import lambada.combinators: compose;
        import lambada.traits: toFunctionType;

        alias l = toFunctionType!(f, L);
        alias r = toFunctionType!(g, R);
        alias onLeft = compose!(failure!(ReturnType!r), f);
        alias onRight = compose!(success!(ReturnType!l), g);

        return this.fold!(onLeft, onRight);
    }

    template map(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        Validation!(L, ReturnType!(toFunctionType!(f, R))) map() {
            import lambada.combinators: identity;
            return this.bimap!(identity, f);
        }
    }

    auto fold(alias f, alias g)() {
        import sumtype: match;
        return this._.match!(
            (Failure!L l) => f(l._),
            (Success!R r) => g(r._),
        );
    }

    static if (is(R: Validation!(D, G), D, G) && is(D == L)) {
        Validation!(L, G) flatten() {
            import lambada.combinators: identity;
            return this.chain!identity;
        }
    }

    alias _ this;
}

alias ValidationMeta(T) = Validation!(T, typeof(null)).Meta;
