module lambada.either;

struct Left(T) {
    T _;
    alias _ this;
}

template left(R) {
    Either!(L, R) left(L)(L x) {
        return Either!(L, R)(Left!L(x));
    }
}

struct Right(T) {
    T _;
    alias _ this;
}

template right(L) {
    Either!(L, R) right(R)(R x) {
        return Either!(L, R)(Right!R(x));
    }
}

struct Either(L, R) {
    import std.traits: arity, isCallable, ReturnType;

    import lambada.traits: hasConcat, toFunctionType;

    import sumtype: SumType;
    alias type = SumType!(Left!L, Right!R);

    type _;

    this(Left!L _) {
        this._ = _;
    }

    this(Right!R _) {
        this._ = _;
    }

    static Either of(R x) {
        return right!L(x);
    }

    Either!(R, L) swap() {
        return this.fold!(right!R, left!L);
    }

    static if (isCallable!R && arity!R == 1) {
        import std.traits: Parameters;
        Either!(L, ReturnType!R) ap(Either!(L, Parameters!R[0]) x) {
            return this.chain!(f => x.map!f);
        }
    }

    static if (hasConcat!R) {
        Either concat(Either x) {
            return this.fold!(left!R, a => x.chain!(b => right!L(a.concat(b))));
        }
    }

    // import lambada.maybe;
    // Maybe!R toMaybe() {
        // import lambada.combinators: constant;
        // return this.fold!(constant!(Maybe!R(none)), just);
    // }

    // import lambada.validation;
    // Validation!(L, R) toValidation() {
        // return this.fold!(failure!R, success!L);
    // }

    auto bimap(alias f, alias g)() {
        import lambada.combinators: compose;
        alias l = toFunctionType!(f, L);
        alias r = toFunctionType!(g, R);
        alias onLeft = compose!(left!(ReturnType!r), f);
        alias onRight = compose!(right!(ReturnType!l), g);

        return this.fold!(onLeft, onRight);
    }

    Either!(L, ReturnType!(toFunctionType!(f, R))) map(alias f)() {
        import lambada.combinators: identity;
        return this.bimap!(identity, f);
    }


    template chain(alias f) {
        alias Return = ReturnType!(toFunctionType!(f, R));
        template RightType(T : E!(D, G), alias E, D, G) if (is(T == Either!(D, G)) && is(D == L)) {
            alias RightType = G;
        }
        alias G = RightType!Return;

        Either!(L, G) chain() {
            return this.fold!(left!G, f);
        }
    }

    auto fold(alias f, alias g)() {
        import sumtype: match;
        return this._.match!(
            (Left!L x) => f(x._),
            (Right!R x) => g(x._),
        );
    }

    alias _ this;
}
