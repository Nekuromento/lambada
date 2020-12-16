module GameOfComonads;

import core.thread: Thread;

import std.datetime: dur;
import std.stdio: write;
import std.algorithm: sum, map, filter;
import std.random: Random, uniform;

import lambada.combinators: identity;
import lambada.io: IO;

enum size = 30;

alias Board = bool[][];

// Comonadic Game of Life logic
struct Pos {
    ulong x;
    ulong y;
}

struct Pointer {
    Board board;
    Pos pos;

    Pointer updatePos(Pos x) {
        return Pointer(board, x);
    }

    auto extract() {
        return board[pos.x][pos.y];
    }

    Pointer extend(alias f)() {
        Board board = this.board.dup;
        foreach(x; 0 .. board.length) {
            foreach(y; 0 .. board[x].length) {
                board[x][y] = f(Pointer(board, Pos(x, y)));
            }
        }
        return Pointer(board, pos);
    }
}

enum inBounds = (Pos pos) =>
    pos.x >= 0 && pos.y >= 0 && pos.x < size && pos.y < size;

enum pointerNeighbours = (Pointer pointer) {
    auto offsets = [Pos(-1, -1), Pos(-1, 0), Pos(-1, 1), Pos(0, -1), Pos(0, 1), Pos(1, -1), Pos(1, 0), Pos(1, 1)];
    auto positions = offsets
        .map!(offset => Pos(pointer.pos.x + offset.x, pointer.pos.y + offset.y))
        .filter!inBounds;

    return positions.map!(pos => pointer.updatePos(pos).extract());
};

enum liveNeighbours = (Pointer pointer) =>
    pointerNeighbours(pointer).filter!identity.sum;

enum rules = (Pointer pointer) {
    auto c = pointer.extract();
    auto n = liveNeighbours(pointer);

    return c && (n < 2 || n > 3) ? false : (c && n == 2) || n == 3 || c;
};

enum step = (Board board) => Pointer(board, Pos(0, 0)).extend!rules.board;

enum clearScreen = () =>
    IO!(typeof(null))({
        write("\033[2J\033[1;1H");
        return null;
    });

auto rnd = Random(3);

enum setup = clearScreen;

enum generateBoard = () =>
    IO!Board({
        Board board = new bool[][size];
        foreach(x; 0 .. board.length) {
            board[x] = new bool[size];
            foreach(y; 0 .. board[x].length) {
                board[x][y] = uniform(0.0f, 1.0f, rnd) > 0.85f;
            }
        }
        return board;
    });

enum drawBoard = (Board board) =>
    clearScreen().chain!(_ => IO!(typeof(null))({
        foreach(x; 0 .. board.length) {
            foreach(y; 0 .. board[x].length) {
                if (board[x][y]) {
                    write("[]");
                } else {
                    write("  ");
                }
            }
            write('\n');
        }
        return null;
    }));

enum sleep = () =>
    IO!(typeof(null))({
        Thread.sleep(dur!"msecs"(66));
        return null;
    });

IO!(typeof(null)) loop(Board board) {
    return drawBoard(board)
        .chain!(_ => sleep())
        .chain!(_ => board.step.loop);
}

void example() {
    auto program = setup()
        .chain!(_ => generateBoard())
        .chain!loop
    ;

    // Perform effects!
    program.unsafePerform();
}

version (Example_GameOfComonads) {
    void main() { example(); }
}
