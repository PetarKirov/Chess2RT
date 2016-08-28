module chess.board;

import chess.piece;

import std.algorithm, std.array, std.container;

struct BoardPosition
{
	int x;
	int y;
	this(int x, int y)
	{
		this.x = x;
		this.y = y;
	}
	bool isValid()
	{
		return x < 8 && x > -1 && y < 8 && y > -1;
	}
}

struct LastMove
{
	BoardPosition pos1;
	Piece pieceAtPos1;
	BoardPosition pos2;
	Piece pieceAtPos2;
}

struct PlayerSettings
{
	BoardPosition kingPosition = BoardPosition(-1,-1);
}

class Board
{
    private
    {
        Piece[8][8] board;
		PieceColor activePlayer = PieceColor.White;
		PlayerSettings[2] playersSettings;
		LastMove lastMove;
    }

	this()
	{
		reset();
	}
	this(char[64] asciiRepresentation)
    {
		reset(asciiRepresentation);
    }

	void reset()
	{
		char[64] s = "rnbqkbnr" ~
			"pppppppp" ~
			"........" ~
			"........" ~
			"........" ~
			"........" ~
			"PPPPPPPP" ~
			"RNBQKBNR";
		reset(s);
	}

	void reset(char[64] asciiRepresentation)
	{
		foreach(i, c; asciiRepresentation)
		    this[i/8,i%8] = generatePiece(c, this, BoardPosition(i/8, i%8));
		updatePieces();
	}
	ref Piece opIndex(BoardPosition pos)
	{
		return board[pos.x][pos.y];
	}

    ref Piece opIndex(uint r, uint c)
    {
        return board[r][c];
    }

	bool isCheck()
	{
		BoardPosition activeKing = (activePlayer == PieceColor.White) ? playersSettings[0].kingPosition : playersSettings[1].kingPosition;
		if(activeKing.isValid())
		{
			for(uint i=0; i<8; ++i)
			{
				for(uint j=0; j<8; ++j)
				{
					Piece currentPiece = board[i][j];
					if(currentPiece && currentPiece.canHit(activeKing))
					{
						return true;
					}
				}
			}
		}
		return false;
	}

	bool isMate()
	{
		// TODO
		return false;
	}

	PieceColor getActivePlayer()
	{
		return activePlayer;
	}
	void switchActivePlayer()
	{
		activePlayer = (activePlayer == PieceColor.White) ? PieceColor.Black : PieceColor.White;
	}

private:
	void simpleMove(BoardPosition pos1, BoardPosition pos2)
	{
		Piece piece1 = this[pos1];
		Piece piece2 = this[pos2];

		this[pos1] = null;
		this[pos2] = piece1;
		updateLastMove(pos1, piece1, pos2, piece2);
		updatePieces();
	}

	void updateLastMove(BoardPosition pos1, Piece pieceAtPos1, 
						BoardPosition pos2, Piece pieceAtPos2)
	{
		this.lastMove.pos1 = pos1;
		this.lastMove.pieceAtPos1 = pieceAtPos1;
		this.lastMove.pos2 = pos2;
		this.lastMove.pieceAtPos2 = pieceAtPos2;
	}

	void undoLastMove()
	{
		this[lastMove.pos1] = lastMove.pieceAtPos1;
		this[lastMove.pos2] = lastMove.pieceAtPos2;
		updatePieces();
	}

	void updatePieces()
	{
		PlayerSettings* whiteSettings = &playersSettings[0];
		PlayerSettings* blackSettings = &playersSettings[1];
		for(uint i=0; i<8; ++i)
		{
			for(uint j=0; j<8; ++j)
			{
				Piece currentPiece = board[i][j];
				if(currentPiece)
				{
					currentPiece.position = BoardPosition(i,j);
					if(currentPiece.getType() == PieceEnum.King)
					{
						if(currentPiece.color == PieceColor.White)
						{
							whiteSettings.kingPosition = currentPiece.position;
						}
						else
						{
							blackSettings.kingPosition = currentPiece.position;
						}
					}
				}
			}
		}

		for(uint i=0; i<8; ++i)
		{
			for(uint j=0; j<8; ++j)
			{
				Piece currentPiece = board[i][j];
				if(currentPiece)
				{
					currentPiece.updatePositionsToHit();
				}
			}
		}
	}
public:
	bool move(BoardPosition pos1, BoardPosition pos2)
	{
		if(this[pos1] is null || !this[pos1].canHit(pos2))
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
		return true;
	}
	unittest
	{
		Board b = new Board("........" ~
							"p......." ~
							"..p.p..." ~
							"....P..." ~
							".....p.." ~
							"....P.P." ~
							"........" ~
							"........");
		assert(b.move(BoardPosition(1,0), BoardPosition(3,0)));
		assert(b[3,0] && b[3,0].getType() == PieceEnum.Pawn && b[3,0].position == BoardPosition(3,0));

		assert(!b.move(BoardPosition(2,4), BoardPosition(3,4))); //illegal move

		assert(b.move(BoardPosition(4,5), BoardPosition(5,6))); // take piece with pawn
		assert(!b[4,5]);
		assert(b[5,6].color == PieceColor.Black && b[5,6].getType() == PieceEnum.Pawn);

		//test with check
		b = new Board("........" ~
					  "p..k...." ~
					  "..p.p..." ~
					  "....P..." ~
					  "B....p.." ~
					  "....P.P." ~
					  "........" ~
					  "........");
		b.activePlayer = PieceColor.Black;
		assert(!b.move(BoardPosition(2,2), BoardPosition(3,2))); //illegal move, because it would leave black king in check
		// check if the illegal move changed anything on the board (shouldnt happen)
		assert(b[2,2] && b[2,2].getType() == PieceEnum.Pawn && b[2,2].position == BoardPosition(2,2)); 
		assert(b.move(BoardPosition(1,0), BoardPosition(2,0))); //legal move, king is protected
	}

	/************************************************************/
	//return value indicates whether to continue or not
	bool appendPosition(ref BoardPosition[] arr, BoardPosition pos, PieceColor color)
	{
		if(pos.x > 7 || pos.x < 0 || pos.y > 7 || pos.y < 0)
			return false;
		Piece current = this[pos];
		if(current is null)
		{
			arr ~= pos;
			return true;
		}
		if(current.color != color)
			arr ~= pos;
		return false;
	}
	BoardPosition[] getUpVertical(PieceColor color, BoardPosition pos)
	{
		BoardPosition[] result;
		result.reserve(7);
		for(int x = pos.x - 1; ; --x)
		{
			if(appendPosition(result, BoardPosition(x, pos.y), color))
				continue;
			break;
		}
		return result;
	}

	BoardPosition[] getDownVertical(PieceColor color, BoardPosition pos)
	{
		BoardPosition[] result;
		result.reserve(7);
		for(int x = pos.x + 1; ; ++x)
		{
			if(appendPosition(result, BoardPosition(x, pos.y), color))
				continue;
			break;
		}
		return result;
	}

	BoardPosition[] getLeftHorizontal(PieceColor color, BoardPosition pos)
	{
		BoardPosition[] result;
		result.reserve(7);
		for(int y = pos.y - 1; ; --y)
		{
			if(appendPosition(result, BoardPosition(pos.x, y), color))
				continue;
			break;
		}
		return result;
	}

	BoardPosition[] getRightHorizontal(PieceColor color, BoardPosition pos)
	{
		BoardPosition[] result;
		result.reserve(7);
		for(int y = pos.y + 1; ; ++y)
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
		for(int x = pos.x - 1, y = pos.y + 1; ; --x, ++y)
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
		for(int x = pos.x - 1, y = pos.y - 1; ; --x, --y)
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
		for(int x = pos.x + 1, y = pos.y - 1; ; ++x, --y)
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
		for(int x = pos.x + 1, y = pos.y + 1; ; ++x, ++y)
		{
			if(appendPosition(result, BoardPosition(x, y), color))
				continue;
			break;
		}
		return result;
	}
}
