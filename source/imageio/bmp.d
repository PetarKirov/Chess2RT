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

ushort toNativeInt16(Singature s)
{
	return littleEndianToNative!ushort(s);
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

/// The size of of the DIB Header
enum DIBHeaderVersion : int
{
	BITMAPCOREHEADER = 12, //or OS21XBITMAPHEADER
	OS22XBITMAPHEADER = 64,
	BITMAPINFOHEADER = 40,
	BITMAPV2INFOHEADER = 52,
	BITMAPV3INFOHEADER = 56,
	BITMAPV4HEADER = 108,
	BITMAPV5HEADER = 124
}

/// Old  version - mostly unused
struct DIBCoreHeader
{
	DIBHeaderVersion headerSize;
	ushort width;
	ushort height;
	ushort colorPlanesCount;
	ushort bitsPerPixel;
}

static assert (DIBCoreHeader.sizeof == DIBHeaderVersion.BITMAPCOREHEADER);

