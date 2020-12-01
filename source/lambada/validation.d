module lambada.validation;

struct Success(T) {
    T _;
    alias _ this;
}

template success(L) {
    Validation!(L, R) success(R)(R x) {
        return Validation!(L, R)(Success!R(x));
    }
}

struct Failure(T) {
    T _;
    alias _ this;
}

template failure(R) {
    Validation!(L, R) failure(L)(L x) {
        return Validation!(L, R)(Failure!L(x));
    }
}

struct Validation(L, R) {
    import lambada.traits: hasConcat;

    import sumtype: SumType;
    alias type = SumType!(Failure!L, Success!R);

    type _;

    this(Success!R _) {
        this._ = _;
    }

    static Validation of(R x) {
        return success!L(x);
    }

    this(Failure!L _) {
        this._ = _;
    }

    import std.traits: arity, isCallable;
    static if (isCallable!R && arity!R == 1 && hasConcat!L) {
        import std.traits: Parameters, ReturnType;

        Validation!(L, ReturnType!R) ap(Validation!(L, Parameters!R[0]) x) {
            return this.fold!(
                    a => x.fold!(
                        b => failure!(ReturnType!R)(a.concat(b)),
                        _ => failure!(ReturnType!R)(a)
                    ),
                    f => x.map!f
            );
        }
    }

    static if (hasConcat!L && hasConcat!R) {
        Validation concat(Validation x) {
            import lambada.combinators: identity;
            return this.fold!(
                a => x.bimap!(b => a.concat(b), identity),
                a => x.map!(b => a.concat(b))
            );
        }
    }

    import lambada.maybe;
    Maybe!R toMaybe() {
        import lambada.combinators: constant;
        return this.fold!(constant!(Maybe!R(none)), just);
    }

    import lambada.either;
    Either!(L, R) toEither() {
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

    alias _ this;
}
