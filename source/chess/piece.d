module chess.piece;

import std.bitmanip, std.conv;

enum PieceType
{
    Empty =     0,

    Pawn =      1,
    Knight =    2,
    Bishop =    3,
    Rook =      4,
    Queen =     5,
    King =      6,

    PieceMask = 7,
}

enum PieceColor
{
    White = 0,
    Black = 1
}

enum ArmyType
{
    Classic =   0,
    Nemesis =   1,
    Empowered = 2,
    Reaper =    3,
    TwoKings =  4,
    Animals =   5,

    ArmyTypeMask = 7
}

struct Piece
{
    this(PieceType type, PieceColor color, ArmyType army)
    {
        this.pieceType = type;
        this.color = color;
        this.armyType = army;
    }

    this(PieceEnum e)
    {
        import std.stdio;

        this.pieceType =    std.conv.to!PieceType(  e & PieceEnum.PieceMask);
        this.color =        std.conv.to!PieceColor( (e & PieceEnum.ColorMask) >> 3);
        this.armyType =     std.conv.to!ArmyType(   (e & PieceEnum.ArmyTypeMask) >> 4);
    }
    this(char c)
    {
        this(toPieceEnum(c));
    }

    mixin(bitfields!(
        PieceType,  "pieceType",    3,
        PieceColor, "color",        1,
        ArmyType,   "armyType",     3,
        bool,       "",             1)); //reserved

    PieceEnum opCast(T)() const if (is(T : PieceEnum))
    {
        return cast(PieceEnum)*cast(byte*)&this;
    }

    void toString(scope void delegate(const(char)[]) sink) const
    {
        sink(armyType.to!string);
        sink(" ");
        sink(color.to!string);
        sink(" ");
        sink(pieceType.to!string);
    }
}

void test()
{
    import std.stdio;

    foreach (army; __traits(allMembers, ArmyType))
        foreach (color; __traits(allMembers, PieceColor))
            foreach (type; __traits(allMembers, PieceType))
            {
                auto p = Piece(
                    __traits(getMember, PieceType, type),
                    __traits(getMember, PieceColor, color),
                    __traits(getMember, ArmyType, army));

                auto e = p.to!PieceEnum;

                writef("%08b %s", *cast(byte*)&p, e);

                if  ((e & PieceEnum.PieceMask) == PieceEnum.PieceMask ||
                     (e & PieceEnum.ColoredPieceMask) == PieceEnum.ColoredPieceMask ||
                     (e & PieceEnum.ArmyTypeMask) == PieceEnum.ArmyTypeMask)
                {
                    writeln();
                    continue;
                }

                writeln("\tASCII Representation: ", to!char(e));
            }
}

//BitField:
// 7|6 5 4|3|2 1 0
// R ARMTY C PIECE
// R - Reserved, ARMTY - ArmyType from Chess2 (0 for standard chess)
// C - Color (0 for white, 1 for black),
// PIECE - piece type (empty, pawn, knight, bishop, rook, Queen, king)
enum PieceEnum : byte
{
    Empty = 0,
    Pawn = 1,
    Knight = 2,
    Bishop = 3,
    Rook = 4,
    Queen = 5,
    King = 6,

    PieceMask = 7,

    //Color
    White = 0,
    Black = 1 << 3,

    ColorMask = Black,

    //Colored pieces
    White_Pawn = 1,
    White_Knight = 2,
    White_Bishop = 3,
    White_Rook = 4,
    White_Queen = 5,
    White_King = 6,

    Black_Pawn =    Black + Pawn,
    Black_Knight =  Black + Knight,
    Black_Bishop =  Black + Bishop,
    Black_Rook =    Black + Rook,
    Black_Queen =   Black + Queen,
    Black_King =    Black + King,

    ColoredPieceMask = 15,

    //Army types
    Classic = 0 << 4,
    Nemesis = 1 << 4,
    Empowered = 2 << 4,
    Reaper = 3 << 4,
    TwoKings = 4 << 4,
    Animals = 5 << 4,

    ArmyTypeMask = cast(byte)((1 << 6) + (1 << 5)+ (1 << 4))
}


//ASCII representation
char toCharA(PieceEnum p)
{
    switch (p &= PieceEnum.ColoredPieceMask)
    {
        case PieceEnum.Empty: return '.';

        case PieceEnum.White_Pawn: return 'P';
        case PieceEnum.White_Knight: return 'N';
        case PieceEnum.White_Bishop: return 'B';
        case PieceEnum.White_Rook: return 'R';
        case PieceEnum.White_Queen: return 'Q';
        case PieceEnum.White_King: return 'K';

        case PieceEnum.Black_Pawn: return 'p';
        case PieceEnum.Black_Knight: return 'n';
        case PieceEnum.Black_Bishop: return 'b';
        case PieceEnum.Black_Rook: return 'r';
        case PieceEnum.Black_Queen: return 'q';
        case PieceEnum.Black_King: return 'k';

        default: return '@';//assert(0);
    }
}

import std.stdio;

private:
PieceEnum toPieceEnum(char c)
{
    switch (c)
    {
        case '.': return PieceEnum.Empty;

        case 'P': return PieceEnum.White_Pawn;
        case 'N': return PieceEnum.White_Knight;
        case 'B': return PieceEnum.White_Bishop;
        case 'R': return PieceEnum.White_Rook;
        case 'Q': return PieceEnum.White_Queen;
        case 'K': return PieceEnum.White_King;

        case 'p': return PieceEnum.Black_Pawn;
        case 'n': return PieceEnum.Black_Knight;
        case 'b': return PieceEnum.Black_Bishop;
        case 'r': return PieceEnum.Black_Rook;
        case 'q': return PieceEnum.Black_Queen;
        case 'k': return PieceEnum.Black_King;

        default: writeln(c, " ", cast(int)c, "Here!"); assert(0);
    }
}
