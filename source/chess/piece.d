module chess.piece;

import std.bitmanip, std.conv;
import chess.board;

enum PieceColor
{
    White = 0,
    Black = 1
}

//enum ArmyType
//{
//    Classic =   0,
//    Nemesis =   1,
//    Empowered = 2,
//    Reaper =    3,
//    TwoKings =  4,
//    Animals =   5,
//
//    ArmyTypeMask = 7
//}

Piece* generatePiece(char c, Board* board)
{
	return null;
}

abstract class Piece
{

	PieceColor color;
	BoardPosition position;
	Board* parentBoard;
	BoardPosition[] positionsToHit;

	this(PieceColor color, BoardPosition initialPosition, Board* parentBoard)
	{
		this.color = color;
	}
	
	abstract BoardPosition[] getPositionsToHitImpl();

	void updatePositionsToHit()
	{
		positionsToHit = getPositionsToHitImpl();
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

    void toString(scope void delegate(const(char)[]) sink) const
    {
        return;
    }
}

class Pawn : Piece
{
	this(PieceColor color, BoardPosition initialPosition, Board* parentBoard)
	{
		super(color, initialPosition, parentBoard);
	}

	override BoardPosition[] getPositionsToHitImpl()
	{
		BoardPosition[] result;
		result.reserve(8);
		if(color == PieceColor.White && position.x > 0)
		{
			BoardPosition front = BoardPosition(position.x - 1, position.y);
			bool emptyFront = ((*parentBoard)[front] == null);
			Piece * leftFront = (position.y > 0) ? (*parentBoard)[position.x-1, position.y-1] : null;
			Piece * rightFront = (position.y < 7) ? (*parentBoard)[position.x-1, position.y+1] : null;
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
				if((*parentBoard)[4, position.y] == null)
				{
					result ~= BoardPosition(4, position.y);
				}
			}
		}
		else if(color == PieceColor.Black && position.x < 7)
		{
			BoardPosition front = BoardPosition(position.x + 1, position.y);
			bool emptyFront = ((*parentBoard)[front] == null);
			Piece * leftFront = (position.y > 0) ? (*parentBoard)[position.x+1, position.y-1] : null;
			Piece * rightFront = (position.y < 7) ? (*parentBoard)[position.x+1, position.y+1] : null;
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
				if((*parentBoard)[3, position.y] == null)
				{
					result ~= BoardPosition(3, position.y);
				}
			}
		}
		return result;
	}
}

class Rook : Piece
{
	this(PieceColor color, BoardPosition initialPosition, Board* parentBoard)
	{
		super(color, initialPosition, parentBoard);
	}

	override BoardPosition[] getPositionsToHitImpl()
	{
		BoardPosition[] result;
		
		return result;
	}
}
void test()
{
	//import std.stdio;
	//
	//foreach (army; __traits(allMembers, ArmyType))
	//    foreach (color; __traits(allMembers, PieceColor))
	//        foreach (type; __traits(allMembers, PieceType))
	//        {
	//            auto p = Piece(
	//                __traits(getMember, PieceType, type),
	//                __traits(getMember, PieceColor, color),
	//                __traits(getMember, ArmyType, army));
	//
	//            auto e = p.to!PieceEnum;
	//
	//            writef("%08b %s", *cast(byte*)&p, e);
	//
	//            if  ((e & PieceEnum.PieceMask) == PieceEnum.PieceMask ||
	//                 (e & PieceEnum.ColoredPieceMask) == PieceEnum.ColoredPieceMask ||
	//                 (e & PieceEnum.ArmyTypeMask) == PieceEnum.ArmyTypeMask)
	//            {
	//                writeln();
	//                continue;
	//            }
	//
	//            writeln("\tASCII Representation: ", to!char(e));
	//        }
}

//BitField:
// 7|6 5 4|3|2 1 0
// R ARMTY C PIECE
// R - Reserved, ARMTY - ArmyType from Chess2 (0 for standard chess)
// C - Color (0 for white, 1 for black),
// PIECE - piece type (empty, pawn, knight, bishop, rook, Queen, king)
//enum PieceEnum : byte
//{
//    Empty = 0,
//    Pawn = 1,
//    Knight = 2,
//    Bishop = 3,
//    Rook = 4,
//    Queen = 5,
//    King = 6,
//
//    PieceMask = 7,
//
//    //Color
//    White = 0,
//    Black = 1 << 3,
//
//    ColorMask = Black,
//
//    //Colored pieces
//    White_Pawn = 1,
//    White_Knight = 2,
//    White_Bishop = 3,
//    White_Rook = 4,
//    White_Queen = 5,
//    White_King = 6,
//
//    Black_Pawn =    Black + Pawn,
//    Black_Knight =  Black + Knight,
//    Black_Bishop =  Black + Bishop,
//    Black_Rook =    Black + Rook,
//    Black_Queen =   Black + Queen,
//    Black_King =    Black + King,
//
//    ColoredPieceMask = 15,
//
//    //Army types
//    Classic = 0 << 4,
//    Nemesis = 1 << 4,
//    Empowered = 2 << 4,
//    Reaper = 3 << 4,
//    TwoKings = 4 << 4,
//    Animals = 5 << 4,
//
//    ArmyTypeMask = cast(byte)((1 << 6) + (1 << 5)+ (1 << 4))
//}

import std.stdio;

