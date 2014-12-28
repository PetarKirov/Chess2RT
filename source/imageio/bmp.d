module imageio.bmp;

import std.bitmanip, std.stdio;
import ae.utils.graphics.image;
import rt.exception;
import imageio.exception;
import std.exception : enforce;

void loadBmp(C)(ref Image!C result, string filePath)
{
	auto file = File(filePath);
	auto fileHeader = file.readStruct!BmpFileHeader();
	auto version_ = file.readStruct!DIBVersion;

	file.seek(BmpFileHeader.sizeof, 0);

	enforce(fileHeader.signature == FileSignature.Win,
			new ImageIOException("Only file headers beginning with 'BM' are supported!"));

	auto offset = fileHeader.offsetToPixelArray;

	Ver ver = cast(Ver)version_;
	final switch (ver)
	{
		case Ver.V0:
			loadImpl!(C,Ver.V0)(result, file, offset); break;

		case Ver.V1:
			loadImpl!(C, Ver.V1)(result, file, offset); break;

		case Ver.V2:
			loadImpl!(C, Ver.V2)(result, file, offset); break;

		case Ver.V3:
			loadImpl!(C, Ver.V3)(result, file, offset); break;

		case Ver.V4:
			loadImpl!(C, Ver.V4)(result, file, offset); break;

		case Ver.V5:
			loadImpl!(C, Ver.V5)(result, file, offset); break;
	}
}

private void loadImpl(C, DIBVersion V)(ref Image!C result, File file, uint offsetToPixelArray)
{
	import std.algorithm : among;

	auto header = file.readStruct!(DIBHeader!V);

	enforce(header.colorPlanesCount == 1,
			new ErrorLoadingImageException("Can not load .bmp file with multiple color planes!"));

	enforce(header.bpp.among(1, 2, 4, 8, 16, 24, 32, 64),
			new ErrorLoadingImageException("Can not load .bmp file with such bpp!"));

	result.alloc(header.width, header.height);

	// ========= Read Palette ===========

	alias PaletteElem = WinPaletteElement!V;

	PaletteElem[] palette;

	// 1, 2, 4 and 8 bpp images use a palette.
	// Images with higher bpp can also contain a palette,
	// but it is used only for optimization purposes on 
	// some devices and NOT for indexing,
	// so we can skip reading it.
	if (header.bpp.among(1, 2, 4, 8))
	{
		static if (V == DIBVersion.BITMAPCOREHEADER)
		{
			uint paletteSize = 2 ^^ header.bpp;
		}
		else static if (V >= DIBVersion.BITMAPINFOHEADER)
		{
			uint paletteSize = header.colorsUsed ? header.colorsUsed : 2 ^^ header.bpp;
		}

		palette = new PaletteElem[paletteSize];
		auto read = file.rawRead(palette);

		enforce(read.length == palette.length,
				new ErrorLoadingImageException());
	}

	//  ======== Read Pixels ============

	// We need to jump directly to the pixel array,
	// instead of relying on the current position
	// in the file being correct.
	file.seek(offsetToPixelArray, 0);

	// rowSize = bpp/8 * width + (bpp/8) mod 4
	size_t rowSize = ((header.bpp * header.width + 31) / 32) * 4;

	ubyte[] row = new ubyte[rowSize];

	// - If header.height > 0 scanlines are stored from the bottom up
	// - If header.height < 0 scanlines are stored
	// top down (can not be compressed) - used for Ver == V0 (BITMAPCOREHEADER )

	foreach_reverse (y; 0 .. header.height)
	{
		file.rawRead(row);

		if (header.bpp == 24)
		{
			auto s = header.bpp / 8;

			foreach (x; 0 .. header.width)
			{
				auto pixel = row[x * s .. (x + 1) * s ]; // B8 G8 R8
				result[x, y] = C(pixel[2], pixel[1], pixel[0]);
			}
		}
		else if (header.bpp <= 8)
		{
			immutable bpp = header.bpp;
			immutable mask = (2 ^^ bpp) - 1;
			immutable maxShift = 8 / bpp;

			foreach (i, pack; row)
			{				
				foreach_reverse (s; 0 .. maxShift)
				{
					auto idx = (pack >> (bpp * s)) & mask;
					PaletteElem pixel = palette[idx];
					result[i * maxShift + maxShift - (s + 1), y] =
						C(pixel.red, pixel.green, pixel.blue);
				}
			}
		}
	}
	
}

private T readStruct(T)(File f)
{
	T[1] tmp = void;

	f.rawRead(tmp);

	return tmp[0];
}

struct Image(C)
{
	size_t width;
	size_t height;
	C[] pixels;

	alias w = width;
	alias h = height;
	
	this(size_t w, size_t h)
	{
		alloc(w, h);
	}

@safe pure nothrow:

	void alloc(size_t width, size_t height)
	{
		this.width = width;
		this.height = height;
		if (pixels.length < width * height)
			pixels.length = width * height;
	}

	inout auto ref opIndex(size_t x, size_t y) inout
	{
		return scanline(y)[x];
	}

	C opIndexAssign(C value, size_t x, size_t y)
	{
		return scanline(y)[x] = value;
	}

	inout(C)[] scanline(size_t y) inout
	{
		assert(y >= 0 && y < height);
		return pixels[width * y .. width * (y + 1)];
	}
}

enum FileSignature : ubyte[2]
{
	Win 				= cast(ubyte[2])['B', 'M'],
	OS2_Bitmap_Array 	= cast(ubyte[2])['B', 'A'],
	OS2_Color_Icon 		= cast(ubyte[2])['C', 'I'],
	OS2_ColorPointer	= cast(ubyte[2])['C', 'P'],
	OS2_Icon 			= cast(ubyte[2])['I', 'C'],
	OS2_Pointer			= cast(ubyte[2])['P', 'T']
}

/// The size of of the DIB Header
enum DIBVersion : int
{
	BITMAPCOREHEADER =		12, //or OS21XBITMAPHEADER
	//OS22XBITMAPHEADER =	64, unsupported for now (it makes the code cleaner)
	BITMAPINFOHEADER =		40,
	BITMAPV2INFOHEADER =	52,
	BITMAPV3INFOHEADER =	56,
	BITMAPV4INFOHEADER =	108,
	BITMAPV5INFOHEADER =	124
}

// Convinence alias to DIBVersion.
// For internal use only.
private enum Ver
{
	V0 = DIBVersion.BITMAPCOREHEADER, 
	//OS22XBITMAPHEADER =	64, unsupported for now (it makes the code cleaner)
	V1 = DIBVersion.BITMAPINFOHEADER,
	V2 = DIBVersion.BITMAPV2INFOHEADER,
	V3 = DIBVersion.BITMAPV3INFOHEADER,
	V4 = DIBVersion.BITMAPV4INFOHEADER,
	V5 = DIBVersion.BITMAPV5INFOHEADER
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

align(2) struct BmpFileHeader
{
align(1):
	FileSignature signature;
	uint fileSize;
	ushort _reserved1;
	ushort _reserved2;
	uint offsetToPixelArray;
}

static assert (BmpFileHeader.sizeof == 14);

/// Device-independent bitmap (DIB) Header
struct DIBHeader(DIBVersion V)
{
	union
	{
		uint size;
		DIBVersion version_;
	}

	static if (V == DIBVersion.BITMAPCOREHEADER)
	{
		short width;
		short height;
		ushort colorPlanesCount;
		ushort bpp;
	}

	static if (V >= DIBVersion.BITMAPINFOHEADER)
	{
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
	}

	static if (V >= DIBVersion.BITMAPV2INFOHEADER)
	{
		WinBitfieldsMasks!V bitMasks;
	}

	static if (V >= DIBVersion.BITMAPV4INFOHEADER)
	{
		uint colorSpaceType;
		CIE_XYZ_Triple colorSpaceEndpoints;

		/* Gamma coordinates scale values */
		uint gammaRed;
		uint gammaGreen;
		uint gammaBlue;
	}

	static if (V >= DIBVersion.BITMAPV5INFOHEADER)
	{
		uint intent;
		uint profileData;
		uint profileSize;
		uint reserved;
	}
}

static assert (DIBHeader!(DIBVersion.BITMAPCOREHEADER).sizeof == DIBVersion.BITMAPCOREHEADER);
static assert (DIBHeader!(DIBVersion.BITMAPINFOHEADER).sizeof == DIBVersion.BITMAPINFOHEADER);
static assert (DIBHeader!(DIBVersion.BITMAPV2INFOHEADER).sizeof == DIBVersion.BITMAPV2INFOHEADER);
static assert (DIBHeader!(DIBVersion.BITMAPV3INFOHEADER).sizeof == DIBVersion.BITMAPV3INFOHEADER);
static assert (DIBHeader!(DIBVersion.BITMAPV4INFOHEADER).sizeof == DIBVersion.BITMAPV4INFOHEADER);
static assert (DIBHeader!(DIBVersion.BITMAPV5INFOHEADER).sizeof == DIBVersion.BITMAPV5INFOHEADER);

struct WinBitfieldsMasks(DIBVersion V) if (V >= DIBVersion.BITMAPV2INFOHEADER)
{
align(1):
	uint redBitMask;
	uint greenBitMask;
	uint blueBitMask;
	
	static if (V >= DIBVersion.BITMAPV3INFOHEADER)
	{
		uint alphaMask;
	}	
}

align(1) struct WinPaletteElement(DIBVersion V)
{
	ubyte blue;
	ubyte green;
	ubyte red;

	static if (V >= DIBVersion.BITMAPINFOHEADER)
	{
		ubyte alpha;
	}
}

static assert (WinPaletteElement!(DIBVersion.BITMAPCOREHEADER).sizeof == 3);
static assert (WinPaletteElement!(DIBVersion.BITMAPINFOHEADER).sizeof == 4);

private alias _WPE1 = WinPaletteElement!(DIBVersion.BITMAPCOREHEADER);
private alias _WPE1Arr = _WPE1[2];
static assert (_WPE1Arr.sizeof == 6);

private alias _WPE2 = WinPaletteElement!(DIBVersion.BITMAPINFOHEADER);
private alias _WPE2Arr = _WPE2[2];
static assert (_WPE2Arr.sizeof == 8);

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

static assert (CIE_XYZ_Triple.sizeof == 36);

double horizontalDPI(Ver V)(DIBHeader!v header) if (v >= V.V1)
{
	return header.horzResolution / 100.0 * 2.54;
}

double verticalDPI(Ver V)(DIBHeader!V header) if (v >= V.V1)
{
	return header.vertResolution / 100.0 * 2.54;
}

unittest
{
	// Example 1 from http://en.wikipedia.org/wiki/BMP_file_format

	byte[] testImage = 
	[
		// BMP Header
		0x42, 0x4D,					//	"BM"				ID field (42h, 4Dh)
		0x46, 0x00, 0x00, 0x00,		//	70 bytes (54+16)	Size of the BMP file
		0x00, 0x00,					//	Unused				Application specific
		0x00, 0x00,					//	Unused				Application specific
		0x36, 0x00, 0x00, 0x00,		//	54 bytes (14+40)	Offset where the pixel array (bitmap data) can be found

		// DIB Header
		0x28, 0x00, 0x00, 0x00,		//	40 bytes			Number of bytes in the DIB header (from this point)
		0x02, 0x00, 0x00, 0x00,		//	2 pixels			Width of the bitmap in pixels
		0x02, 0x00, 0x00, 0x00,		//	2 pixels			Height of the bitmap in pixels. Positive for bottom to top pixel order.
		0x01, 0x00,					//	1 plane				Number of color planes being used
		0x18, 0x00,					//	24 bits				Number of bits per pixel
		0x00, 0x00, 0x00, 0x00,		//	0					BI_RGB, no pixel array compression used
		0x10, 0x00, 0x00, 0x00,		//	16 bytes			Size of the raw bitmap data (including padding)
		0x13, 0x0B, 0x00, 0x00,		//	2835 pixels/meter	Horizontal print resolution of the image, 72 DPI
		0x13, 0x0B, 0x00, 0x00,		//	2835 pixels/meter	Vertical print resolution of the image, 72 DPI
		0x00, 0x00, 0x00, 0x00,		//	0 colors			Number of colors in the palette
		0x00, 0x00, 0x00, 0x00,		//	0 important colors	0 means all colors are important

		// Start of pixel array (bitmap data)
		0x00, 0x00, 0xFF,			// 0 0 255				Red, Pixel (0,1)
		0xFF, 0xFF, 0xFF,			// 255 255 255			White, Pixel (1,1)
		0x00, 0x00,					// 0 0					Padding for 4 byte alignment (could be a value other than zero)
		0xFF, 0x00, 0x00,			// 255 0 0				Blue, Pixel (0,0)
		0x00, 0xFF, 0x00,			// 0 255 0				Green, Pixel (1,0)
		0x00, 0x00,					// 0 0					Padding for 4 byte alignment (could be a value other than zero)
	];
}

unittest
{
	// Example 2 from http://en.wikipedia.org/wiki/BMP_file_format

	byte[] testImage = 
	[
		// BMP Header
		0x42, 0x4D,					// "BM"						Magic number (unsigned integer 66, 77)
		0x9A, 0x00, 0x00, 0x00,		// 154 bytes (122+32)		Size of the BMP file
		0x00, 0x00,					// Unused					Application specific
		0x00, 0x00,					// Unused					Application specific
		0x7A, 0x00, 0x00, 0x00,		// 122 bytes (14+108)		Offset where the pixel array (bitmap data) can be found

		// DIB Header
		0x6C, 0x00, 0x00, 0x00,		// 108 bytes				Number of bytes in the DIB header (from this point)
		0x04, 0x00, 0x00, 0x00,		// 4 pixels					Width of the bitmap in pixels
		0x02, 0x00, 0x00, 0x00,		// 2 pixels					Height of the bitmap in pixels
		0x01, 0x00,					// 1 plane					Number of color planes being used
		0x20, 0x00,					// 32 bits					Number of bits per pixel
		0x03, 0x00, 0x00, 0x00,		// 3 BI_BITFIELDS			no pixel array compression used
		0x20, 0x00, 0x00, 0x00,		// 32 bytes					Size of the raw bitmap data (including padding)
		0x13, 0x0B, 0x00, 0x00,		// 2835 pixels/meter		Horizontal print resolution of the image, 72 DPI
		0x13, 0x0B, 0x00, 0x00,		// 2835 pixels/meter		Vertical print resolution of the image, 72 DPI
		0x00, 0x00, 0x00, 0x00,		// 0 colors					Number of colors in the palette
		0x00, 0x00, 0x00, 0x00,		// 0 important colors		0 means all colors are important
		0x00, 0x00, 0xFF, 0x00,		// 00FF0000 in big-endian	Red channel bit mask (valid because BI_BITFIELDS is specified)
		0x00, 0xFF, 0x00, 0x00,		// 0000FF00 in big-endian	Green channel bit mask (valid because BI_BITFIELDS is specified)
		0xFF, 0x00, 0x00, 0x00,		// 000000FF in big-endian	Blue channel bit mask (valid because BI_BITFIELDS is specified)
		0x00, 0x00, 0x00, 0xFF,		// FF000000 in big-endian	Alpha channel bit mask
		0x20, 0x6E, 0x69, 0x57,		// little-endian "Win "		LCS_WINDOWS_COLOR_SPACE

		// CIEXYZTRIPLE Color Space endpoints					Unused for LCS "Win " or "sRGB"
		0x00, 0x00, 0x00, 0x00,		// redX
		0x00, 0x00, 0x00, 0x00,     // redY
		0x00, 0x00, 0x00, 0x00,     // redZ
		0x00, 0x00, 0x00, 0x00,     // greenX
		0x00, 0x00, 0x00, 0x00,     // greenY
		0x00, 0x00, 0x00, 0x00,     // greenZ
		0x00, 0x00, 0x00, 0x00,     // blueX
		0x00, 0x00, 0x00, 0x00,     // blueY
		0x00, 0x00, 0x00, 0x00,     // blueZ

		0x00, 0x00, 0x00, 0x00,		// 0 Red Gamma				Unused for LCS "Win " or "sRGB"
		0x00, 0x00, 0x00, 0x00,		// 0 Green Gamma			Unused for LCS "Win " or "sRGB"
		0x00, 0x00, 0x00, 0x00,		// 0 Blue Gamma				Unused for LCS "Win " or "sRGB"

		// Start of the Pixel Array (the bitmap Data)
		0xFF, 0x00, 0x00, 0x7F,		// 255 0 0 127				Blue (Alpha: 127), Pixel (0,1)
		0x00, 0xFF, 0x00, 0x7F,		// 0 255 0 127				Green (Alpha: 127), Pixel (1,1)
		0x00, 0x00, 0xFF, 0x7F,		// 0 0 255 127				Red (Alpha: 127), Pixel (2,1)
		0xFF, 0xFF, 0xFF, 0x7F,		// 255 255 255 127			White (Alpha: 127), Pixel (3,1)
		0xFF, 0x00, 0x00, 0xFF,		// 255 0 0 255				Blue (Alpha: 255), Pixel (0,0)
		0x00, 0xFF, 0x00, 0xFF,		// 0 255 0 255				Green (Alpha: 255), Pixel (1,0)
		0x00, 0x00, 0xFF, 0xFF,		// 0 0 255 255				Red (Alpha: 255), Pixel (2,0)
		0xFF, 0xFF, 0xFF, 0xFF,		// 255 255 255 255			White (Alpha: 255), Pixel (3,0)
	];
}
