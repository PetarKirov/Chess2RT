module chess.game;

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
		if(!isCheck())
		{
			return false;
		}

		Piece king = this[playersSettings[activePlayer].kingPosition];
		BoardPosition[] positionsHitByKing = king.getPositionsToHit();

		// check if king can move anywhere
		foreach (p ; positionsHitByKing)
		{
			simpleMove(king.position, p);

			if(!isCheck())
			{
				undoLastMove();
				return false;
			}
			undoLastMove();
		}

		// check if pieces hitting the king can be blocked
		Piece[] enemyPieces = getPiecesOfColorNoKing( (activePlayer == PieceColor.White) ? PieceColor.Black : PieceColor.White);
		Piece[] friendlyPieces = getPiecesOfColorNoKing(activePlayer);
		Piece[] piecesHittingKing = getPiecesHittingPosition(enemyPieces, king.position);
		// if king can't move and is checked by more than 2 pieces, then it's mate
		if(piecesHittingKing.length > 1)
		{
			return true;
		}
		Piece pieceHittingKing = piecesHittingKing[0];
		return !canBeBlocked(friendlyPieces, pieceHittingKing, king);
	}
	unittest
	{
		Board b = new Board("........" ~
							"........" ~
							"........" ~
							"........" ~
							"........" ~
							"........" ~
							"q......." ~
							"r......K");
		assert(b.isMate());
	}

	PieceColor getActivePlayer()
	{
		return activePlayer;
	}
	void switchActivePlayer()
	{
		activePlayer = (activePlayer == PieceColor.White) ? PieceColor.Black : PieceColor.White;
	}

	bool move(BoardPosition pos1, BoardPosition pos2)
	{
		if(this[pos1].color != activePlayer)
		{
			return false;
		}
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
private:
	Piece[] getPiecesOfColorNoKing(PieceColor color)
	{
		Piece[] result;
		result.reserve(15);
		for(uint i=0; i<8; ++i)
		{
			for(uint j=0; j<8; ++j)
			{
				if(this[i,j] && this[i,j].color == color && this[i,j].getType() != PieceEnum.King)
				{
					result ~= this[i,j];
				}
			}
		}
		return result;
	}
	Piece[] getPiecesHittingPosition(Piece[] pieces, BoardPosition position)
	{
		Piece[] result;
		result.reserve(pieces.length);
		foreach (piece ; pieces)
		{
			if(piece.canHit(position))
			{
				result ~= piece;
			}
		}
		return result;
	}
	bool containsPosition(BoardPosition[] positions, BoardPosition pos)
	{
		foreach (p ; positions)
		{
			if(p == pos)
				return true;
		}
		return false;
	}
	bool canBlockStraightLine(Piece[] friendlyPieces, BoardPosition[] straightLine, BoardPosition targetPosition)
	{
		if(containsPosition(straightLine, targetPosition))
		{
			foreach(p ; friendlyPieces)
			{
				foreach( pos ; straightLine)
				{
					if(p.canHit(pos))
					{
						return true;
					}
				}
			}
		}
		return false;
	}
	bool canBeBlocked(Piece[] friendlyPieces, Piece hittingPiece, Piece targetPiece)
	{
		// check if hitting piece can be taken
		foreach (piece ; friendlyPieces)
		{
			if(piece.canHit(hittingPiece.position))
			{
				return true;
			}
		}
		// check if hitting piece can be blocked
		BoardPosition pos1 = hittingPiece.position;
		BoardPosition pos2 = targetPiece.position;
		PieceColor oppositeColor = (activePlayer == PieceColor.White) ? PieceColor.Black : PieceColor.White;
		return canBlockStraightLine(friendlyPieces, getDownVertical(oppositeColor, pos1), pos2) ||
			canBlockStraightLine(friendlyPieces, getUpVertical(oppositeColor, pos1), pos2) ||
			canBlockStraightLine(friendlyPieces, getRightHorizontal(oppositeColor, pos1), pos2) ||
			canBlockStraightLine(friendlyPieces, getLeftHorizontal(oppositeColor, pos1), pos2) ||
			canBlockStraightLine(friendlyPieces, getUpLeftDiagonal(oppositeColor, pos1), pos2) ||
			canBlockStraightLine(friendlyPieces, getDownLeftDiagonal(oppositeColor, pos1), pos2) ||
			canBlockStraightLine(friendlyPieces, getUpRightDiagonal(oppositeColor, pos1), pos2) ||
			canBlockStraightLine(friendlyPieces, getDownRightDiagonal(oppositeColor, pos1), pos2);
	}
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

/*********************************************************************/
import std.bitmanip, std.conv;

enum PieceColor
{
    White = 0,
    Black = 1
}

enum PieceEnum : byte
{
	Pawn = 1,
	Knight = 2,
	Bishop = 3,
	Rook = 4,
	Queen = 5,
	King = 6
}

Piece generatePiece(char c, Board board, BoardPosition pos)
{
	switch(c)
	{
		case 'K':
			return new King(PieceColor.White, pos, board);
		case 'R':
			return new Rook(PieceColor.White, pos, board);
		case 'N':
			return new Knight(PieceColor.White, pos, board);
		case 'B':
			return new Bishop(PieceColor.White, pos, board);
		case 'Q':
			return new Queen(PieceColor.White, pos, board);
		case 'P':
			return new Pawn(PieceColor.White, pos, board);
		case 'k':
			return new King(PieceColor.Black, pos, board);
		case 'r':
			return new Rook(PieceColor.Black, pos, board);
		case 'n':
			return new Knight(PieceColor.Black, pos, board);
		case 'b':
			return new Bishop(PieceColor.Black, pos, board);
		case 'q':
			return new Queen(PieceColor.Black, pos, board);
		case 'p':
			return new Pawn(PieceColor.Black, pos, board);
		default:
			return null;
	}
}

abstract class Piece
{
	private
	{
		PieceColor color;
		BoardPosition position;
		Board parentBoard;
		BoardPosition[] positionsToHit;
	}

	this(PieceColor color, BoardPosition initialPosition, Board parentBoard)
	{
		this.color = color;
		this.position = initialPosition;
		this.parentBoard = parentBoard;
	}

	bool move(BoardPosition target)
	{
		return parentBoard.move(position, target);
	}
	bool move(int row, int col)
	{
		return move(BoardPosition(row, col));
	}
	abstract PieceEnum getType();

private:
	BoardPosition[] getPositionsToHit()
	{
		return positionsToHit;
	}

	bool canHit(BoardPosition pos)
	{
		foreach (position ; positionsToHit)
		{
			if (position == pos)
			{
				return true;
			}
		}
		return false;
	}
	void updatePositionsToHit()
	{
		positionsToHit = getPositionsToHitImpl();
	}

protected:
	abstract BoardPosition[] getPositionsToHitImpl();
}

class Pawn : Piece
{
	this(PieceColor color, BoardPosition initialPosition, Board parentBoard)
	{
		super(color, initialPosition, parentBoard);
	}

	override PieceEnum getType()
	{
		return PieceEnum.Pawn;
	}
	override BoardPosition[] getPositionsToHitImpl()
	{
		BoardPosition[] result;
		result.reserve(8);
		if(color == PieceColor.White && position.x > 0)
		{
			BoardPosition front = BoardPosition(position.x - 1, position.y);
			bool emptyFront = (parentBoard[front] is null);
			Piece leftFront = (position.y > 0) ? parentBoard[position.x-1, position.y-1] : null;
			Piece rightFront = (position.y < 7) ? parentBoard[position.x-1, position.y+1] : null;
			if(emptyFront) 
			{
				result ~= front;
			}
			if(leftFront && leftFront.color != color)
			{
				result ~= BoardPosition(position.x-1, position.y-1);
			}
			if(rightFront && rightFront.color != color)
			{
				result ~= BoardPosition(position.x-1, position.y+1);
			}
			if(position.x == 6 && emptyFront)
			{
				if(parentBoard[4, position.y] is null)
				{
					result ~= BoardPosition(4, position.y);
				}
			}
		}
		else if(color == PieceColor.Black && position.x < 7)
		{
			BoardPosition front = BoardPosition(position.x + 1, position.y);
			bool emptyFront = (parentBoard[front] is null);
			Piece leftFront = (position.y > 0) ? parentBoard[position.x+1, position.y-1] : null;
			Piece rightFront = (position.y < 7) ? parentBoard[position.x+1, position.y+1] : null;
			if(emptyFront) 
			{
				result ~= front;
			}
			if(leftFront && leftFront.color != color)
			{
				result ~= BoardPosition(position.x+1, position.y-1);
			}
			if(rightFront && rightFront.color != color)
			{
				result ~= BoardPosition(position.x+1, position.y+1);
			}
			if(position.x == 1 && emptyFront)
			{
				if(parentBoard[3, position.y] is null)
				{
					result ~= BoardPosition(3, position.y);
				}
			}
		}
		return result;
	}
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
	Piece p1 = b[1,0];
	BoardPosition[] p1PosToHit = p1.getPositionsToHit();
	assert(p1.getPositionsToHit().length == 2);
	assert(p1PosToHit[0].x == 2 && p1PosToHit[0].y == 0);
	assert(p1PosToHit[1].x == 3 && p1PosToHit[1].y == 0);
	Piece p2 = b[2,2];
	BoardPosition[] p2PosToHit = p2.getPositionsToHit();
	assert(p2.getPositionsToHit().length == 1);
	assert(p2PosToHit[0].x == 3 && p2PosToHit[0].y == 2);

	Piece p3 = b[4,5];
	assert(p3.getPositionsToHit().length == 3);

	Piece p4 = b[5,4];
	assert(p4.getPositionsToHit().length == 2);

	Piece p5 = b[2,4];
	assert(p5.getPositionsToHit().length == 0);
}

class Rook : Piece
{
	this(PieceColor color, BoardPosition initialPosition, Board parentBoard)
	{
		super(color, initialPosition, parentBoard);
	}

	override PieceEnum getType()
	{
		return PieceEnum.Rook;
	}

	override BoardPosition[] getPositionsToHitImpl()
	{
		BoardPosition[] result;
		result.reserve(20);
		result ~= parentBoard.getDownVertical(color, position);
		result ~= parentBoard.getUpVertical(color, position);
		result ~= parentBoard.getRightHorizontal(color, position);
		result ~= parentBoard.getLeftHorizontal(color, position);
		return result;
	}
}
unittest
{
	Board b = new Board("r......." ~
						"........" ~
						".p..r..." ~
						"........" ~
						"....R..." ~
						"....P..." ~
						"........" ~
						"........");
	Piece rook = b[2,4];
	rook.updatePositionsToHit();
	assert(rook.getPositionsToHit().length == 9);
	assert(rook.canHit(BoardPosition(4,4))); // enemy piece
	assert(!rook.canHit(BoardPosition(2,1))); // friendly piece

	Piece rook2 = b[4,4];
	rook2.updatePositionsToHit();
	assert(rook2.getPositionsToHit().length == 9);

	Piece rook3 = b[0,0];
	rook3.updatePositionsToHit();
	assert(rook3.getPositionsToHit().length == 14);
}

class Bishop : Piece
{
	this(PieceColor color, BoardPosition initialPosition, Board parentBoard)
	{
		super(color, initialPosition, parentBoard);
	}

	override PieceEnum getType()
	{
		return PieceEnum.Bishop;
	}

	override BoardPosition[] getPositionsToHitImpl()
	{
		BoardPosition[] result;
		result.reserve(20);
		result ~= parentBoard.getUpLeftDiagonal(color, position);
		result ~= parentBoard.getDownLeftDiagonal(color, position);
		result ~= parentBoard.getUpRightDiagonal(color, position);
		result ~= parentBoard.getDownRightDiagonal(color, position);
		return result;
	}
}
unittest
{
	Board b = new Board("b......." ~
						"........" ~
						"....r..." ~
						"....B..." ~
						"....R..." ~
						"....P..." ~
						"........" ~
						"........");
	Piece bishop = b[0,0];
	bishop.updatePositionsToHit();
	assert(bishop.getPositionsToHit().length == 4);
	assert(bishop.canHit(BoardPosition(4,4)));
	assert(bishop.canHit(BoardPosition(1,1)));
	bishop = b[3,4];
	bishop.updatePositionsToHit();
	assert(bishop.getPositionsToHit().length == 13);
}
class Queen : Piece
{
	this(PieceColor color, BoardPosition initialPosition, Board parentBoard)
	{
		super(color, initialPosition, parentBoard);
	}

	override PieceEnum getType()
	{
		return PieceEnum.Queen;
	}

	override BoardPosition[] getPositionsToHitImpl()
	{
		BoardPosition[] result;
		result.reserve(20);
		result ~= parentBoard.getDownVertical(color, position);
		result ~= parentBoard.getUpVertical(color, position);
		result ~= parentBoard.getRightHorizontal(color, position);
		result ~= parentBoard.getLeftHorizontal(color, position);
		result ~= parentBoard.getUpLeftDiagonal(color, position);
		result ~= parentBoard.getDownLeftDiagonal(color, position);
		result ~= parentBoard.getUpRightDiagonal(color, position);
		result ~= parentBoard.getDownRightDiagonal(color, position);
		return result;
	}
}

class Knight : Piece
{
	this(PieceColor color, BoardPosition initialPosition, Board parentBoard)
	{
		super(color, initialPosition, parentBoard);
	}

	override PieceEnum getType()
	{
		return PieceEnum.Knight;
	}

	override BoardPosition[] getPositionsToHitImpl()
	{
		BoardPosition[] result;
		result.reserve(8);
		parentBoard.appendPosition(result, BoardPosition(position.x + 2, position.y + 1), color);
		parentBoard.appendPosition(result, BoardPosition(position.x + 2, position.y - 1), color);
		parentBoard.appendPosition(result, BoardPosition(position.x + 1, position.y + 2), color);
		parentBoard.appendPosition(result, BoardPosition(position.x + 1, position.y - 2), color);
		parentBoard.appendPosition(result, BoardPosition(position.x - 2, position.y + 1), color);
		parentBoard.appendPosition(result, BoardPosition(position.x - 2, position.y - 1), color);
		parentBoard.appendPosition(result, BoardPosition(position.x - 1, position.y + 2), color);
		parentBoard.appendPosition(result, BoardPosition(position.x - 1, position.y - 2), color);
		return result;
	}
}
unittest
{
	Board b = new Board("n......." ~
						"........" ~
						"....r..." ~
						"........" ~
						"...N...." ~
						".....P.." ~
						"........" ~
						"........");
	Piece n = b[0,0];
	n.updatePositionsToHit();
	assert(n.getPositionsToHit().length == 2);
	assert(n.canHit(BoardPosition(2,1)));
	assert(n.canHit(BoardPosition(1,2)));
	n = b[4, 3];
	n.updatePositionsToHit();
	assert(n.getPositionsToHit().length == 7);
	assert(n.canHit(BoardPosition(2,4))); //enemy piece
	assert(!n.canHit(BoardPosition(5,5))); //friendly piece
}

class King : Piece
{
	this(PieceColor color, BoardPosition initialPosition, Board parentBoard)
	{
		super(color, initialPosition, parentBoard);
	}

	override PieceEnum getType()
	{
		return PieceEnum.King;
	}

	override BoardPosition[] getPositionsToHitImpl()
	{
		BoardPosition[] result;
		parentBoard.appendPosition(result, BoardPosition(position.x + 1, position.y + 1), color);
		parentBoard.appendPosition(result, BoardPosition(position.x + 1, position.y - 1), color);
		parentBoard.appendPosition(result, BoardPosition(position.x + 1, position.y), color);
		parentBoard.appendPosition(result, BoardPosition(position.x, position.y - 1), color);
		parentBoard.appendPosition(result, BoardPosition(position.x, position.y + 1), color);
		parentBoard.appendPosition(result, BoardPosition(position.x - 1, position.y - 1), color);
		parentBoard.appendPosition(result, BoardPosition(position.x - 1, position.y + 1), color);
		parentBoard.appendPosition(result, BoardPosition(position.x - 1, position.y), color);
		return result;
	}
}
