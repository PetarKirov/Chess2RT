module imageio.bmp;

import std.bitmanip, std.stdio;
import ae.utils.graphics.image;
import rt.exception;

void loadBmp(C)(ref Image!C result, string filePath)
{
	//TODO...
}

struct Image(C)
{
	uint width;
	uint height;
	C[] pixels;
	
	this(uint w, uint h)
	{
		alloc(w, h);
	}

	void alloc(int width, int height)
	{
		this.width = width;
		this.height = height;
		if (pixels.length < width * height)
			pixels.length = width * height;
	}

	inout auto ref opIndex(uint x, uint y) inout
	{
		return scanline(y)[x];
	}

	C opIndexAssign(C value, uint x, uint y)
	{
		return scanline(y)[x] = value;
	}

	inout(C)[] scanline(uint y) inout
	{
		assert(y >= 0 && y < height);
		return pixels[width * y .. width * (y + 1)];
	}
}

enum Singature : ubyte[2]
{
	Win 				= cast(ubyte[2])['B', 'M'],
	OS2_Bitmap_Array 	= cast(ubyte[2])['B', 'A'],
	OS2_Color_Icon 		= cast(ubyte[2])['C', 'I'],
	OS2_ColorPointer	= cast(ubyte[2])['C', 'P'],
	OS2_Icon 			= cast(ubyte[2])['I', 'C'],
	OS2_Pointer			= cast(ubyte[2])['P', 'T']
}

/// The size of of the DIB Header
enum Version : int
{
	BITMAPCOREHEADER =		12, //or OS21XBITMAPHEADER
	//OS22XBITMAPHEADER =	64, unsupported for now (it makes the code cleaner)
	BITMAPINFOHEADER =		40,
	BITMAPV2INFOHEADER =	52,
	BITMAPV3INFOHEADER =	56,
	BITMAPV4INFOHEADER =	108,
	BITMAPV5INFOHEADER =	124
}

enum Compression
{
	BI_RGB =			0,
	BI_RLE8 =			1,
	BI_RLE4 =			2,
	BI_BITFIELDS =		3,
	BI_JPEG =			4,
	BI_PNG =			5,
	BI_ALPHABITFIELDS =	6,
	BI_CMYK	=			11,
	BI_CMYKRLE8 =		12,
	BI_CMYKTLE4 =		13
}

align(2) struct BmpHeader
{
align(1):
	ushort signature;
	uint fileSize;
	ushort _reserved1;
	ushort _reserved2;
	uint offsetToPixelArray;
}

static assert (BmpHeader.sizeof == 14);

/// Old  version - mostly unused
struct Win2xBitmapHeader
{
	union
	{
		uint size;
		Version version_;
	}
	
	short width;
	short height;
	ushort colorPlanesCount;
	ushort bpp;
}

static assert (Win2xBitmapHeader.sizeof == Version.BITMAPCOREHEADER);

struct Win2xPaletteElement
{
	ubyte Blue;
	ubyte Green;
	ubyte Red;
}

struct WinBitmapHeader(Version V) if (V >= Version.BITMAPINFOHEADER)
{
	union
	{
		uint size;
		Version version_;
	}

	int width;
	int height;
	ushort colorPlanesCount;
	ushort bpp;

	/* Fields added for Windows 3.x follow this line */
	uint compression;
	uint sizeOfBitmap;
	int  horzResolution;
	int  vertResolution;
	uint colorsUsed;
	uint colorsImportant;

	static if (V >= Version.BITMAPV2INFOHEADER)
	{
		WinBitfieldsMasks!V bitMasks;
	}

	static if (V >= Version.BITMAPV4INFOHEADER)
	{
		uint colorSpaceType;
		CIE_XYZ_Triple colorSpaceEndpoints;

		/* Gamma coordinates scale values */
		uint gammaRed;
		uint gammaGreen;
		uint gammaBlue;
	}

	static if (V >= Version.BITMAPV5INFOHEADER)
	{
		uint intent;
		uint profileData;
		uint profileSize;
		uint reserved;
	}
}

struct WinBitfieldsMasks(Version V)
{
	uint redBitMask;
	uint greenBitMask;
	uint blueBitMask;
	
	static if (V >= Version.BITMAPV3INFOHEADER)
	{
		uint alphaMask;
	}	
}

struct CIE_XYZ_Triple
{
	int redX;
	int redY;
	int redZ;
	int greenX;
	int greenY;
	int greenZ;
	int blueX;
	int blueY;
	int blueZ;
}

static assert (WinBitmapHeader!(Version.BITMAPINFOHEADER).sizeof == Version.BITMAPINFOHEADER);
static assert (WinBitmapHeader!(Version.BITMAPV2INFOHEADER).sizeof == Version.BITMAPV2INFOHEADER);
static assert (WinBitmapHeader!(Version.BITMAPV3INFOHEADER).sizeof == Version.BITMAPV3INFOHEADER);
static assert (WinBitmapHeader!(Version.BITMAPV4INFOHEADER).sizeof == Version.BITMAPV4INFOHEADER);
static assert (WinBitmapHeader!(Version.BITMAPV5INFOHEADER).sizeof == Version.BITMAPV5INFOHEADER);

struct WinPaletteElement(Version V)
{
	ubyte blue;
	ubyte green;
	ubyte red;

	static if (V >= Version.BITMAPV3INFOHEADER)
	{
		ubyte alpha;
	}
}