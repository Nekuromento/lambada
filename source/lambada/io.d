module lambada.io;

struct IO(T) {
    import std.traits: arity, isCallable;

    T delegate() _;

    this(T x) {
        import lambada.combinators: constant;
        alias f = constant!x;
        this._ = &f!();
    }

    static IO of(T x) {
        return IO(x);
    }

    this(F)(F f) if (isCallable!F && arity!F == 0) {
        import lambada.combinators: apply;
        alias x = apply!f;
        this._ = &x!();
    }

    T unsafePerform() {
        return _();
    }

    static if (isCallable!T && arity!T == 1) {
        import std.traits: Parameters, ReturnType;

        IO!(ReturnType!T) ap(IO!(Parameters!T[0]) x) {
            import lambada.combinators: apply;
            return this.chain!(f => x.map!f);
        }
    }

    template map(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        IO!(ReturnType!(toFunctionType!(f, T))) map() {
            import lambada.combinators: compose;
            return this.chain!(compose!(typeof(return), f));
        }
    }

    template chain(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        alias Return = ReturnType!(toFunctionType!(f, T));
        template Type(I : E!D, alias E, D) if (is(I == IO!D)) {
            alias Type = D;
        }
        alias G = Type!Return;

        IO!G chain() {
            //XXX: hack to fix delegates referencing dead objects:
            //     capture local frame instead of this
            auto _unsafePerform = this._;

            return IO!G(() => f(_unsafePerform()).unsafePerform());
        }
    }
}
