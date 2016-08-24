module chess.board;

import chess.piece;

import std.algorithm, std.array, std.container;

struct BoardPosition
{
	uint x;
	uint y;
	this(uint x, uint y)
	{
		this.x = x;
		this.y = y;
	}
}

struct PlayerSettings
{
	BoardPosition kingPosition;
	RedBlackTree!(Piece*) pieces;
	BoardPosition[] lostPieces;
}

struct Board
{
    private
    {
        Piece[64] board;
        uint movesCounter;
		bool isWhitesTurn = true;
		PlayerSettings[2] playersSettings;
    }

	this(char[64] asciiRepresentation)
    {
        foreach(i, c; asciiRepresentation)
            board[i] = Piece(c);
    }

	inout(Piece) opIndex(BoardPosition pos) inout
	{
		return board[(8 - pos.x) * 8 + pos.y];
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

	bool isCheck()
	{
		PlayerSettings* opponentSettings = &playersSettings[isWhitesTurn ? 1 : 0];
		PlayerSettings* playerSettings = &playersSettings[isWhitesTurn ? 1 : 0];
		foreach (piece; opponentSettings.pieces)
		{
			if(piece.canHit(playerSettings.kingPosition))
				return true;
		}
		return false;
	}

	bool isMate()
	{
		//TODO
		return false;
	}

	bool isWhiteTurn()
	{
		return isWhitesTurn;
	}

	Piece moveSimple(BoardPosition pos1, BoardPosition pos2)
	{
		Piece pieceAtPos2 = board[(8 - pos2.x) * 8 + pos2.y];
		this[pos2] = this[pos1];
		this[pos1] = Piece('.');
		return pieceAtPos2;
	}
	bool move(BoardPosition pos1, BoardPosition pos2)
	{
		if(!this[pos1].canHit(pos2))
			return false;
		Piece pieceAtPos2 = moveSimple(pos1, pos2);

		if(isCheck())
		{
			// restoring original
			moveSimple(pos2, pos1);
			this[pos2] = pieceAtPos2;
			return false;
		}
		return true;
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
