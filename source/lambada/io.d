module lambada.io;

struct IO(T) {
    import std.meta: AliasSeq;
    import std.traits: arity, isCallable, ReturnType;

    import lambada.traits: toFunctionType;

    private alias Empty = AliasSeq!();

    T delegate() _;

    this(T x) {
        import lambada.combinators: constant;
        alias f = constant!x;
        this._ = &f!();
    }

    static IO of(T x) {
        return IO(x);
    }

    this(F)(F f) if (isCallable!F) {
        import lambada.combinators: apply;
        alias x = apply!f;
        this._ = &x!();
    }

    T unsafePerform() {
        return _();
    }

    static if (isCallable!T && arity!T == 1) {
        import std.traits: Parameters;
        IO!(ReturnType!T) ap(IO!(Parameters!T[0]) x) {
            import lambada.combinators: apply;
            return this.chain!(f => x.map!f);
        }
    }

    IO!(ReturnType!(toFunctionType!(f, Empty))) map(alias f)() {
        import lambada.combinators: compose;
        return this.chain!(compose!(typeof(return), f));
    }

    template chain(alias f) {
        alias Return = ReturnType!(toFunctionType!(f, Empty));
        template Type(I : E!D, alias E, D) if (is(I == IO!D)) {
            alias Type = D;
        }
        alias G = Type!Return;

        IO!G chain() {
            return IO!G(() => f(this.unsafePerform()).unsafePerform());
        }
    }
}
