module chess.piece;

import std.bitmanip, std.conv;
import chess.board;

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
	PieceColor color;
	BoardPosition position;
	Board parentBoard;
	BoardPosition[] positionsToHit;

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
	abstract PieceEnum getType();

	void updatePositionsToHit()
	{
		positionsToHit = getPositionsToHitImpl();
	}

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
	p1.updatePositionsToHit();
	BoardPosition[] p1PosToHit = p1.getPositionsToHit();
	assert(p1.getPositionsToHit().length == 2);
	assert(p1PosToHit[0].x == 2 && p1PosToHit[0].y == 0);
	assert(p1PosToHit[1].x == 3 && p1PosToHit[1].y == 0);
	Piece p2 = b[2,2];
	p2.updatePositionsToHit();
	BoardPosition[] p2PosToHit = p2.getPositionsToHit();
	assert(p2.getPositionsToHit().length == 1);
	assert(p2PosToHit[0].x == 3 && p2PosToHit[0].y == 2);

	Piece p3 = b[4,5];
	p3.updatePositionsToHit();
	assert(p3.getPositionsToHit().length == 3);

	Piece p4 = b[5,4];
	p4.updatePositionsToHit();
	assert(p4.getPositionsToHit().length == 2);

	Piece p5 = b[2,4];
	p5.updatePositionsToHit();
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

