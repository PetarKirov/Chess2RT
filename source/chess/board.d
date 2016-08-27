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
	bool isValid()
	{
		return x < 8 && y < 8;
	}
}

struct LastMove
{
	BoardPosition pos1;
	Piece* pieceAtPos1;
	BoardPosition pos2;
	Piece* pieceAtPos2;
}

struct PlayerSettings
{
	BoardPosition kingPosition;
}

class Board
{
    private
    {
        Piece*[8][8] board;
		PieceColor activePlayer = PieceColor.White;
		PlayerSettings[2] playersSettings;
		LastMove lastMove;
    }

	this()
	{
		char[64] s = "rnbqkbnr" ~
			"pppppppp" ~
			"........" ~
			"........" ~
			"........" ~
			"........" ~
			"PPPPPPPP" ~
			"RNBQKBNR";
		this(s);
	}
	this(char[64] asciiRepresentation)
    {
		//foreach(i, c; asciiRepresentation)
		//    this[i/8,i%8] = generatePiece(c, &this);
    }

	ref Piece* opIndex(BoardPosition pos)
	{
		return board[pos.x][pos.y];
	}

    ref Piece* opIndex(uint r, uint c)
    {
        return board[r][c];
    }

	bool isCheck()
	{
		BoardPosition activeKing = (activePlayer == PieceColor.White) ? playersSettings[0].kingPosition : playersSettings[1].kingPosition;
		for(uint i=0; i<8; ++i)
		{
			for(uint j=0; j<8; ++j)
			{
				Piece* currentPiece = board[i][j];
				if(currentPiece && currentPiece.canHit(activeKing))
				{
					return true;
				}
			}
		}
		return false;
	}

	bool isMate()
	{
		return false;
	}

	PieceColor getActivePlayer()
	{
		return activePlayer;
	}
	private:
	void simpleMove(BoardPosition pos1, BoardPosition pos2)
	{
		Piece* piece1 = this[pos1];
		Piece* piece2 = this[pos2];

		this[pos1] = null;
		this[pos2] = piece1;
		updateLastMove(pos1, piece1, pos2, piece2);
	}
	private:
	void updateLastMove(BoardPosition pos1, Piece* pieceAtPos1, 
						BoardPosition pos2, Piece* pieceAtPos2)
	{
		this.lastMove.pos1 = pos1;
		this.lastMove.pieceAtPos1 = pieceAtPos1;
		this.lastMove.pos2 = pos2;
		this.lastMove.pieceAtPos2 = pieceAtPos2;
	}
	private:
	void undoLastMove()
	{
		this[lastMove.pos1] = lastMove.pieceAtPos2;
		this[lastMove.pos2] = lastMove.pieceAtPos1;
	}
	bool move(BoardPosition pos1, BoardPosition pos2)
	{
		if(!this[pos1] || !this[pos1].canHit(pos2))
		{
			return false;
		}

		simpleMove(pos1, pos2);

		if(isCheck())
		{
			//illegal move, undo
			undoLastMove();
			return false;
		}

		//update all figures
		return true;
	}

    void toString(scope void delegate(const(char)[]) sink) const
    {
    }
	/************************************************************/
	//return value indicates whether to continue or not
	private
	{
		bool appendPosition(BoardPosition[] arr, BoardPosition pos, PieceColor color)
		{
			Piece* current = this[pos];
			if(current == null)
			{
				arr ~= pos;
				return true;
			}
			if(current.color != color)
				arr ~= pos;
			return false;
		}
		BoardPosition[] getLeftHorizontal(PieceColor color, BoardPosition pos)
		{
			BoardPosition[] result;
			result.reserve(7);
			for(int x = pos.x - 1; x >= 0; --x)
			{
				if(appendPosition(result, BoardPosition(x, pos.y), color))
					continue;
				break;
			}
			return result;
		}

		BoardPosition[] getRightHorizontal(PieceColor color, BoardPosition pos)
		{
			BoardPosition[] result;
			result.reserve(7);
			for(int x = pos.x + 1; x < 8; ++x)
			{
				if(appendPosition(result, BoardPosition(x, pos.y), color))
					continue;
				break;
			}
			return result;
		}

		BoardPosition[] getUpVertical(PieceColor color, BoardPosition pos)
		{
			BoardPosition[] result;
			result.reserve(7);
			for(int y = pos.y - 1; y >= 0; --y)
			{
				if(appendPosition(result, BoardPosition(pos.x, y), color))
					continue;
				break;
			}
			return result;
		}

		BoardPosition[] getDownVertical(PieceColor color, BoardPosition pos)
		{
			BoardPosition[] result;
			result.reserve(7);
			for(int y = pos.y + 1; y < 8; ++y)
			{
				if(appendPosition(result, BoardPosition(pos.x, y), color))
					continue;
				break;
			}
			return result;
		}

		BoardPosition[] getUpRightDiagonal(PieceColor color, BoardPosition pos)
		{
			BoardPosition[] result;
			result.reserve(7);
			for(int x = pos.x - 1, y = pos.y + 1; x >=0 && y < 8 ; --x, ++y)
			{
				if(appendPosition(result, BoardPosition(x, y), color))
					continue;
				break;
			}
			return result;
		}

		BoardPosition[] getUpLeftDiagonal(PieceColor color, BoardPosition pos)
		{
			BoardPosition[] result;
			result.reserve(7);
			for(int x = pos.x - 1, y = pos.y - 1; x >=0 && y >= 0 ; --x, --y)
			{
				if(appendPosition(result, BoardPosition(x, y), color))
					continue;
				break;
			}
			return result;
		}

		BoardPosition[] getDownRightDiagonal(PieceColor color, BoardPosition pos)
		{
			BoardPosition[] result;
			result.reserve(7);
			for(int x = pos.x + 1, y = pos.y - 1; x < 8 && y >= 0; ++x, --y)
			{
				if(appendPosition(result, BoardPosition(x, y), color))
					continue;
				break;
			}
			return result;
		}

		BoardPosition[] getDownLeftDiagonal(PieceColor color, BoardPosition pos)
		{
			BoardPosition[] result;
			result.reserve(7);
			for(int x = pos.x + 1, y = pos.y + 1; x < 8 && y < 8 ; ++x, ++y)
			{
				if(appendPosition(result, BoardPosition(x, y), color))
					continue;
				break;
			}
			return result;
		}
	}
}

void test()
{
    //Board b = Board();
}
