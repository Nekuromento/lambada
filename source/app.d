import std.typecons: tuple;
import std.stdio: writeln;

import lambada.maybe;
import lambada.either;
import lambada.reader;
import lambada.validation;
import lambada.io;
import lambada.state;

struct str {
    string _;

    str concat(str x) {
        return str(_ ~ x._);
    }

    alias _ this;
}

void main() {
    Maybe!int x = just(4);
    Maybe!int y = none;
    auto z = x.map!(a => a * 2).chain!(a => y.orElse(just(2)).chain!(b => just(a + b)));

    auto f = just((int x) => x / 2);
    z = f.ap(z);
    writeln(z.getOrElse(0));

    writeln();

    alias R = Reader!(int, int);
    auto r = R(4);
    auto g = R((int x) => x + 2);
    auto a = ask!int;
    auto b = r.map!(x => x * 2).chain!(x => g.chain!(y => a.chain!(q => R((int z) => q + x + y + z))));
    writeln(b.run(10));
    auto h = Reader!(int, int delegate(int))((int x) => (int y) => y + x);
    writeln(h.ap(b).run(10));

    writeln();

    auto s = right!bool(3);
    auto t = right!bool(4);
    auto u = s.map!(x => x + 2).chain!(x => t.chain!(y => right!bool(x + y)));
    writeln(u);
    auto i = left!(int delegate(int))(true);
    writeln(i.ap(u));

    writeln();

    auto n = success!str(str("3"));
    auto m = failure!str(str("hello "));
    auto o = failure!str(str("world"));

    writeln(n.concat(m).concat(o));

    writeln();

    auto j = State!(int, string)("X");
    auto p = put(5);
    auto sp = p.chain!(_ => j.map!(_ => _));
    writeln(sp.run(0));

    auto k = get!int.chain!(x => put(x + 1).chain!(_ => get!int.chain!(y => State!(int, int)(y + x))));
    writeln(k.run(256));

    auto q = State!(int, int delegate(int))((int x) => x * 2);
    auto e = State!(int, int)(3);
    writeln(q.ap(e).run(1));
}
