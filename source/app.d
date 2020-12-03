import std.typecons: tuple;
import std.stdio: writeln;

import lambada.either;
import lambada.eitherT;
import lambada.io;
import lambada.maybe;
import lambada.maybeT;
import lambada.reader;
import lambada.state;
import lambada.validation;
import lambada.writer;

struct str {
    static str empty() {
        return str.init;
    }

    string[] _;

    str opBinary(string op)(str x) if (op == "~") {
        return str(this._ ~ x._);
    }

    alias _ this;
}

void main() {
    alias M = MaybeMeta;
    Maybe!int x = M.of(4);
    Maybe!int y = M.empty;
    auto z = x.map!(a => a * 2).chain!(a => y.orElse(just(2)).chain!(b => just(a + b)));

    auto f = just((int x) => x / 2);
    z = f.ap(z);
    writeln(z.getOrElse(0));
    writeln(just(just("hello") ~ just(" ") ~ just("world")).flatten);

    writeln();

    alias R = Reader!(int, int);
    auto r = R.of(4);
    auto g = R((int x) => x + 2);
    auto a = ask!int;
    auto b = r.map!(x => x * 2).chain!(x => g.chain!(y => a.chain!(q => R((int z) => q + x + y + z))));
    writeln(b.run(10));
    auto h = Reader!(int, int delegate(int))((int x) => (int y) => y + x);
    writeln(h.ap(b).run(10));

    writeln(just(g));
    writeln(just(g).sequence());
    writeln(just(g).sequence().run(10));

    alias ReaderMaybe = MaybeTMeta!(ReaderMeta!int);
    auto ra = ReaderMaybe.of((int x) => x + 2);
    auto rb = ReaderMaybe.of(3);
    writeln(ra.ap(rb).run.run(10));

    writeln();

    auto s = right!bool(3);
    auto t = right!bool(4);
    auto u = s.map!(x => x + 2).chain!(x => t.chain!(y => right!bool(x + y)));
    writeln(u);
    auto i = left!(int delegate(int))(true);
    writeln(i.ap(u));

    alias MaybeEither = EitherTMeta!(MaybeMeta, int);
    auto me = MaybeEither.of("hi");
    auto mf = MaybeEither.of((string x) => x ~ "!");
    writeln(mf.ap(me).swap().run.sequence());

    writeln();

    auto n = success!string("3");
    auto m = failure!string("hello ");
    auto o = failure!string("world");

    writeln(n ~ m ~ o);

    writeln();

    alias S = StateMeta!int;
    auto j = S.of("X");
    auto p = put(5);
    auto sp = p.chain!(_ => j.map!(_ => _));
    writeln(sp.run(0));

    auto k = get!int.chain!(x => put(x + 1).chain!(_ => get!int.chain!(y => S.of(y + x))));
    writeln(k.run(256));

    auto q = S.of((int x) => x * 2);
    auto e = S.of(3);
    writeln(q.ap(e).run(1));

    writeln();

    alias I = IOMeta;
    auto v = I.of((int x) => x * 2);
    auto c = I.of(3);
    writeln(v.ap(c).map!(x => x + 2).unsafePerform());

    alias W = Writer!(str, int);
    auto wa = W(() => tuple(0, str(["hello"])));
    auto wb = tell(str(["world"]));
    writeln(wa.chain!(x => wb.chain!(_ => W.of(x))).listen().censor!(_ => _).run());
}
