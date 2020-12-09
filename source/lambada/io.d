module lambada.io;

struct IO(T) {
    struct Meta {
        alias Constructor(U) = IO!U;
        alias Parameter = T;
        static IO!U of(U)(U x) {
            import lambada.combinators: constant;
            alias f = constant!x;
            return IO!U(&f!());
        }
    }

    T delegate() _;

    alias of = Meta.of;

    import std.traits: isCallable;
    this(F)(F f) if (isCallable!f) {
        import lambada.combinators: apply;
        alias x = apply!f;
        this._ = &x!();
    }

    T unsafePerform() {
        return _();
    }
    alias opCall = unsafePerform;

    import std.traits: arity;
    static if (isCallable!T && arity!T == 1) {
        import std.traits: Parameters, ReturnType;

        IO!(ReturnType!T) ap(IO!(Parameters!T[0]) x) {
            return this.chain!(f => x.map!f);
        }
    }

    template map(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        IO!(ReturnType!(toFunctionType!(f, T))) map() {
            import lambada.combinators: compose;
            return this.chain!(compose!(this.of, f));
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

    static if (is(T: IO!U, U)) {
        IO!U flatten() {
            import lambada.combinators: identity;
            return this.chain!identity;
        }
    }
}

alias IOMeta = IO!(typeof(null)).Meta;
