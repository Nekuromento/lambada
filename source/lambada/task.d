module lambada.task;

import std.parallelism: PTask = Task;

import lambada.io: IO;

Task!T fromIO(T)(IO!T x) {
    import std.parallelism: task;
    return Task!T(task!((IO!T x) => x())(x));
}

struct Task(T) {
    struct Meta {
        alias Constructor(U) = Task!U;
        alias Parameter = T;
        static Task!U of(U)(U x) {
            import std.parallelism: task;

            import lambada.combinators: identity;

            return Task!U(task!(identity!U)(x));
        }
        alias fromIO = .fromIO;
    }

    T delegate() _;

    alias of = Meta.of;

    this(alias fun, Args...)(auto ref PTask!(fun, Args) t) {
        this._ = {
            import std.parallelism: taskPool;
            taskPool.put(t);
            return t.spinForce();
        };
    }

    this(alias fun, Args...)(PTask!(fun, Args)* t) {
        this._ = {
            import std.parallelism: taskPool;
            taskPool.put(t);
            return t.spinForce();
        };
    }

    T fork() {
        return _();
    }
    alias opCall = fork;

    import std.traits: isCallable, arity;
    static if (isCallable!T && arity!T == 1) {
        import std.traits: Parameters, ReturnType;

        Task!(ReturnType!T) ap(Task!(Parameters!T[0]) x) {
            return this.chain!(f => x.map!f);
        }
    }

    template map(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        Task!(ReturnType!(toFunctionType!(f, T))) map() {
            import lambada.combinators: compose;
            return this.chain!(compose!(this.of, f));
        }
    }

    template chain(alias f) {
        import std.traits: ReturnType;

        import lambada.traits: toFunctionType;

        alias Return = ReturnType!(toFunctionType!(f, T));
        template Type(I : E!D, alias E, D) if (is(I == Task!D)) {
            alias Type = D;
        }
        alias G = Type!Return;

        static auto run(T delegate() x, Task!G delegate(T) fn) {
            return fn(x()).fork();
        }

        Task!G chain() {
            import std.parallelism: task;
            Task!G delegate(T) fn = (T x) => f(x);
            return Task!G(task!run(this._, fn));
        }
    }

    static if (is(T: Task!U, U)) {
        Task!U flatten() {
            import lambada.combinators: identity;
            return this.chain!identity;
        }
    }
}

alias TaskMeta = Task!(typeof(null)).Meta;
