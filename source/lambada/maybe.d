module lambada.maybe;

struct None {}

immutable none = None();

alias Some(T) = T;

Maybe!T just(T)(T x) if (!is(T == None)) {
    return Maybe!T(x);
}

struct Maybe(T) {
    import sumtype: SumType;
    alias type = SumType!(Some!T, None);

    type _;

    this(None _) {
        this._ = _;
    }

    static Maybe empty() {
        return Maybe(none);
    }

    this(Some!T _) {
        this._ = _;
    }

    static Maybe of(T x) {
        return just(x);
    }

    bool isSome() {
        import lambada.combinators: constant;
        return this.fold!(constant!true, constant!false);
    }

    bool isNone() {
        return !isSome();
    }

    Maybe!T orElse(Maybe!T x) {
        import lambada.combinators: constant;
        return this.fold!(just, constant!x);
    }

    T getOrElse(T x) {
        import lambada.combinators: constant, identity;
        return this.fold!(identity, constant!x);
    }

    import std.traits: arity, isCallable;
    static if (isCallable!T && arity!T == 1) {
        import std.traits: Parameters, ReturnType;

        Maybe!(ReturnType!T) ap(Maybe!(Parameters!T[0]) x) {
            return this.chain!(f => x.map!f);
        }
    }

    import lambada.traits: hasConcat;
    static if (hasConcat!T) {
        Maybe concat(Maybe x) {
            return this.chain!(a => x.map!(b => a.concat(b)));
        }
    }

    import lambada.either;
    Either!(L, T) toEither(L)(L x) {
        import lambada.combinators: compose, constant;
        return this.fold!(right!L, compose!(left!T, constant!x));
    }

    import lambada.validation;
    Validation!(L, R) toValidation(L)(L x) {
        import lambada.combinators: compose, constant;
        return this.fold!(success!L, compose!(failure!T, constant!x));
    }

    U reduce(alias f, U)(U b) {
        import lambada.combinators: constant;
        return this.fold!(a => f(b, a), constant!b);
    }

    U reduceRight(alias f, U)(U b) {
        import lambada.combinators: constant;
        return this.fold!(a => f(a, b), constant!b);
    }

    Maybe filter(alias f)() {
        return this.fold!(x => f(x) ? just(x) : Maybe(none), identity);
    }

    template map(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        Maybe!(ReturnType!(toFunctionType!(f, T))) map() {
            import lambada.combinators: compose;
            return this.chain!(compose!(just, f));
        }
    }

    template chain(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        alias Return = ReturnType!(toFunctionType!(f, T));
        template Type(R : E!D, alias E, D) if (is(R == Maybe!D)) {
            alias Type = D;
        }
        alias U = Type!Return;

        Maybe!U chain() {
            import lambada.combinators: constant;
            return this.fold!(f, constant!(Maybe!U(none)));
        }
    }

    auto fold(alias f, alias g)() {
        import sumtype: match;
        return this._.match!(
            (Some!T x) => f(x),
            (None _) => g(_),
        );
    }

    alias _ this;
}
