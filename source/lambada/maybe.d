module lambada.maybe;

private struct None {}
private struct Some(T) { T _; }

Maybe!None none() {
    return Maybe!None();
}

Maybe!T just(T)(T x) {
    return Maybe!T(Some!T(x));
}

template tryCatch(alias f) {
    import std.meta: AliasSeq;
    import std.traits: ReturnType;

    import lambada.traits: toFunctionType;

    alias Empty = AliasSeq!();

    Maybe!(ReturnType!(toFunctionType!(f, Empty))) tryCatch() {
        scope(failure) return none;
        return just(f());
    }
}

struct Maybe(T) {
    struct Meta {
        alias Constructor(U) = Maybe!U;
        alias Parameter = T;
        alias of = just;
        alias empty = none;
        alias just = .just;
        alias none = .none;
    }

    alias of = Meta.of;
    alias empty = Meta.empty;

    static if (!is(T == None)) {
        import sumtype: SumType;

        SumType!(Some!T, None) _;
        alias _ this;

        this(None _) {
            this._ = _;
        }

        this(Some!T _) {
            this._ = _;
        }

        this(Maybe!None _) {
            this._ = None();
        }
    }

    bool isSome() {
        import lambada.combinators: constant;
        return this.fold!(constant!true, constant!false);
    }

    bool isNone() {
        return !isSome();
    }

    Maybe orElse(Maybe x) {
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

    import lambada.traits: isSemigroup;
    static if (isSemigroup!T) {
        Maybe opBinary(string op)(Maybe x) if (op == "~") {
            return this.chain!(a => x.map!(b => a ~ b));
        }

        Maybe concat(Maybe x) {
            return this ~ x;
        }
    }

    import lambada.either: Either;
    Either!(L, T) toEither(L)(L x) {
        import lambada.either: right, left;
        import lambada.combinators: compose, constant;
        return this.fold!(right!L, compose!(left!T, constant!x));
    }

    import lambada.validation: Validation;
    Validation!(L, R) toValidation(L)(L x) {
        import lambada.validation: success, failure;
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

    static if (is(T: Maybe!U, U)) {
        Maybe!U flatten() {
            import lambada.combinators: identity;
            return this.chain!identity;
        }
    }

    auto fold(alias f, alias g)() {
        static if (is(T == None)) {
            return g(None());
        } else {
            import sumtype: match;
            return this._.match!(
                (Some!T x) => f(x._),
                (None _) => g(_),
            );
        }
    }

    import lambada.traits: isApplicative;
    static if (isApplicative!T) {
        T.Meta.Constructor!(Maybe!(T.Meta.Parameter)) sequence() {
            import lambada.combinators: identity;
            return this.traverse!identity;
        }
    }

    template traverse(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        alias Return = ReturnType!(toFunctionType!(f, T));

        static if (isApplicative!Return) {
            Return.Meta.Constructor!(Maybe!(Return.Meta.Parameter)) traverse() {
                return this.fold!(
                    x => f(x).map!just,
                    _ => Return.of(Maybe!(Return.Meta.Parameter)(none))
                );
            }
        }
    }
}

alias MaybeMeta = Maybe!(typeof(null)).Meta;
