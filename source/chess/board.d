module chess.board;

import chess.piece;

import std.algorithm, std.array;

struct Board
{
    private
    {
        Piece[64] board;
        uint movesCounter;
    }

    inout(Piece) opIndex(Col c, Row r) inout
    {
        return board[(8 - r) * 8 + c];
    }

    inout(Piece) opIndex(const(char)[2] c) inout
    {
        return this[
            cast(Col)(c[0] - 'a'),
            cast(Row)(c[1] - '0' )
        ];
    }

    this(char[64] asciiRepresentation)
    {
        foreach(i, c; asciiRepresentation)
            board[i] = Piece(c);
    }

    void toString(scope void delegate(const(char)[]) sink) const
    {
        foreach (row; 0 .. 8)
        {
            if (row != 0) sink("\n");

            sink(board[row * 8 .. row * 8 + 8]
                .map!((piece) => toCharA(cast(PieceEnum)piece))
                .array);

        }
    }
}

enum Row
{
    r1,
    r2,
    r3,
    r4,
    r5,
    r6,
    r7,
    r8
}

enum Col
{
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h
}


void test()
{
    char[64] s = "rnbqkbnr" ~
                 "pppppppp" ~
                 "........" ~
                 "........" ~
                 "........" ~
                 "........" ~
                 "PPPPPPPP" ~
                 "RNBQKBNR";

    Board b = Board(s);

    import std.stdio;
    writeln(b);

    writeln(b["a1"]);
    writeln(b["b2"]);
    writeln(b["d8"]);
}
