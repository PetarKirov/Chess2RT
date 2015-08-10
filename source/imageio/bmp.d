module imageio.bmp;

import std.algorithm : among;
import std.conv : to;
import std.exception : enforce;
import std.math : lrint;
import std.typecons : Flag;
import imageio.exception, imageio.image, imageio.buffer,
	imageio.meta : TemplateSwitchOn, PrepareHeadFor, Type;

struct BMPImage(ColorType = void)
{
	BmpFileHeader file_header;
	DIBHeader!(Ver.V5) dib_header;
	Image!ColorType pixels;
}

DIBHeader!(Ver.V5) toV5Header(Ver V)(DIBHeader!V oldHeader)
{
	DIBHeader!(Ver.V5) result;

	foreach (member; __traits(allMembers, DIBHeader!V))
	{
		mixin("result." ~ member ~
			" = cast(typeof(result."~member~"))oldHeader." ~ member ~ ";");
	}

	return result;
}

Image!ColorType loadBmpImage(ColorType)(UntypedBuffer file_stream) pure
{
	return loadBmp!(ColorType, LoadHeaderOnly.no)(file_stream).pixels;
}

Image!ColorType loadBmpHeader(ColorType)(UntypedBuffer file_stream) pure
{
	return loadBmp!(ColorType, LoadHeaderOnly.yes)(file_stream);
}

alias LoadHeaderOnly  = Flag!"loadHeaderOnly";

/// Extracts an Image!C from a BMP file stream.
BMPImage!ColorType loadBmp(ColorType, Flag!"loadHeaderOnly" headerOnly)
	(UntypedBuffer file_stream) pure
{
	alias loadBmpImplT = PrepareHeadFor!(loadBmpImpl, ColorType, headerOnly);
	mixin TemplateSwitchOn!(Ver, loadBmpImplT) TemplateSwitch;

	auto file_header = file_stream.read!BmpFileHeader;
	auto ver = file_stream.read!Ver;

	enforce(file_header.signature == FileSignature.Win,
		new ImageIOException(
			"Only files beginning with 'BM' are supported!"));

	return TemplateSwitch.call(ver, file_stream, file_header);
}

private BMPImage!ColorType loadBmpImpl(ColorType, Flag!"loadHeaderOnly" headerOnly, Ver V)
	(ref UntypedBuffer file_stream, BmpFileHeader file_header) pure
{
	// ========= Read Header ============

	// The Device Independant Bitmap (DIB) header is after the BmpFileHeader,
	// so we need to skip the first BmpFileHeader.sizeof bytes.

	file_stream.seek(BmpFileHeader.sizeof);
	auto header = file_stream.read!(DIBHeader!V);

	// Check the DIB header's bpp and color planes count
	enforce(header.colorPlanesCount == 1,
		new ErrorLoadingImageException(
			format( "Only .bmp files with 1 color plane are supported. Not: %s",
					header.colorPlanesCount)));

	enforce(header.bpp.among(1, 2, 4, 8, 16, 24, 32, 64),
		new ErrorLoadingImageException(
			format( "Only .bmp files with 1, 2, 4, 8, 16, 24, "
					"32 or 64 bpp are supported. Not: %s",
					header.bpp)));

	// ========= Read Palette ===========

	// 1, 2, 4 and 8 bpp images use a palette.
	// Images with higher bpp can also contain a palette,
	// but it is used only for optimization purposes on
	// some devices and NOT for indexing,
	// so we can skip reading it.

	alias PaletteItem = WinPaletteElement!V;

	const(PaletteItem)[] palette;

	if (header.bpp.among(1, 2, 4, 8))
	{
		static if (V == DIBVersion.BITMAPCOREHEADER)
		{
			uint paletteSize = 2 ^^ header.bpp;
		}
		else static if (V >= DIBVersion.BITMAPINFOHEADER)
		{
			uint paletteSize = header.colorsUsed ?
				header.colorsUsed : 2 ^^ header.bpp;
		}

		palette = file_stream.readArray!PaletteItem(paletteSize);
	}

	//  ======== Read Pixels ============

	// We need to jump directly to the pixel array,
	// instead of relying on the current position
	// in the file being correct.
	file_stream.seek(file_header.offsetToPixelArray);

	// rowSize = bpp/8 * width + (bpp/8) mod 4
	size_t rowSize = ((header.bpp * header.width + 31) / 32) * 4;

	auto result = BMPImage!ColorType(file_header, toV5Header(header));

	static if (headerOnly)
		return result;

	result.pixels = Image!ColorType(header.width, header.height);

	// - If header.height > 0 scanlines are stored from the bottom up
	// - If header.height < 0 scanlines are stored
	// top down (can not be compressed) - used for Ver == V0 (BITMAPCOREHEADER)

	immutable row_size = header.bpp / 8 * header.width;
	immutable row_size_padding = ((header.bpp * header.width + 31) / 32) * 4;

	if (header.bpp == 24)
	{
		alias Pixel = WinPaletteElement!(Ver.V0);

		foreach_reverse (y; 0 .. header.height)
		{
			const Pixel[] row = file_stream.readArray!Pixel(header.width);
			file_stream.skip(row_size_padding - row_size);

			foreach (x; 0 .. header.width)
			{
				// TODO: How to handle construction of color objects
				// more generically?
				result.pixels[x, y] = ColorType(row[x].to!uint);
			}
		}
	}
	else if (header.bpp == 32)
	{
		alias Pixel = WinPaletteElement!(Ver.V1);

		foreach_reverse (y; 0 .. header.height)
		{
			const Pixel[] row = file_stream.readArray!Pixel(header.width);
			file_stream.skip(row_size_padding - row_size);

			foreach (x; 0 .. header.width)
			{
				result.pixels[x, y] = ColorType(row[x].to!uint);
			}
		}
	}
	else if (header.bpp <= 8)
	{
		foreach_reverse (y; 0 .. header.height)
		{
			const ubyte[] row = file_stream.readArray!ubyte(header.width);

			immutable bpp = header.bpp;
			immutable mask = (2 ^^ bpp) - 1;
			immutable maxShift = 8 / bpp;

			foreach (i, pack; row)
			{
				foreach_reverse (s; 0 .. maxShift)
				{
					auto idx = (pack >> (bpp * s)) & mask;
					result.pixels[i * maxShift + maxShift - (s + 1), y] =
						ColorType(palette[idx].to!uint);
				}
			}
		}
	}
	else
		assert(0, "Not implemented: bpp > 8 && bpp != 24 && bpp != 32");

	return result;
}

void saveBmp(C)(in Image!C img, ref UntypedBuffer file_stream) pure
{
	import std.bitmanip : nativeToLittleEndian;

	enum ver = Ver.V1;
	enum bpp = 24;
	uint fileSize = (BmpFileHeader.sizeof + DIBHeader!(ver).sizeof +
		bpp / 8 * img.width * img.height).to!uint;

	auto fileHeader = BmpFileHeader(
		FileSignature.Win, fileSize, 0, 0,
		BmpFileHeader.sizeof + ver);

	auto dibHeader = DIBHeader!ver(
		ver,
		img.width.to!int, img.height.to!int,
		1, bpp,
		Compression.BI_RGB,
		(fileSize - (BmpFileHeader.sizeof + ver)).to!uint,
		72.dpiToPPM,
		72.dpiToPPM,
		0, 0);

	file_stream = UntypedBuffer(fileSize);

	file_stream.writeStruct(fileHeader);
	file_stream.writeStruct(dibHeader);

	auto row_converted = new ubyte[3][img.width];

	foreach_reverse (y; 0 .. img.height)
	{
		auto row = img.scanline(y);

		foreach (x; 0 .. img.width)
		{
			auto pixel = row[x].to!uint;
			row_converted[x] = nativeToLittleEndian(pixel)[0 .. 3];
		}

		file_stream.write(row_converted);
	}
}

double horizontalDPI(Ver V)(DIBHeader!v header) pure if (v >= V.V1)
{
	return header.horzResolution.ppmToDPI;
}

double verticalDPI(Ver V)(DIBHeader!V header) pure if (v >= V.V1)
{
	return header.vertResolution.ppmToDPI;
}

/// Converts a value in pixels-per-meter to dots-per-inch.
double ppmToDPI(double ppm) pure { return ppm / 100.0 * 2.54; }

/// Converts a value in dots-per-inch to pixels-per-meter.
int dpiToPPM(double dpi) pure { return cast(int)lrint(dpi * 100.0 / 2.54); }

enum FileSignature : char[2]
{
	Win 				= "BM",
	OS2_Bitmap_Array 	= "BA",
	OS2_Color_Icon 		= "CI",
	OS2_ColorPointer	= "CP",
	OS2_Icon 			= "IC",
	OS2_Pointer			= "PT",
}

/// The size / version of the DIB Header
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
enum Ver : DIBVersion
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

enum LogicalColorSpace : char[4]
{
	LCS_CALIBRATED_RGB = 	[0, 0, 0, 0],
	LCS_sRGB = 					"BGRs",
	LCS_WINDOWS_COLOR_SPACE = 	" niW"
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
struct DIBHeader(Ver V)
{
	DIBVersion version_;

	static if (V == Ver.V0)
	{
		short width;
		short height;
		ushort colorPlanesCount;
		ushort bpp;
	}

	static if (V >= Ver.V1)
	{
		int width;
		int height;
		ushort colorPlanesCount;
		ushort bpp; // bits per pixel

		/* Fields added for Windows 3.x follow this line */
		uint compression;
		uint sizeOfPixelArray; // in bytes
		int  pixelsPerMeterX;
		int  pixelsPerMeterY;
		uint colorsUsed;
		uint colorsImportant;
	}

	static if (V >= Ver.V2)
	{
		WinBitfieldsMasks!V bitMasks;
	}

	static if (V >= Ver.V4)
	{
		LogicalColorSpace colorSpaceType;
		CIE_XYZ_Triple colorSpaceEndpoints;

		/* Gamma coordinates scale values */
		uint gammaRed;
		uint gammaGreen;
		uint gammaBlue;
	}

	static if (V >= Ver.V5)
	{
		uint intent;
		uint profileData;
		uint profileSize;
		uint reserved;
	}
}

static assert (DIBHeader!(Ver.V0).sizeof ==  12); // BITMAPCOREHEADER
static assert (DIBHeader!(Ver.V1).sizeof ==  40); // BITMAPINFOHEADER
static assert (DIBHeader!(Ver.V2).sizeof ==  52); // BITMAPV2INFOHEADER
static assert (DIBHeader!(Ver.V3).sizeof ==  56); // BITMAPV3INFOHEADER
static assert (DIBHeader!(Ver.V4).sizeof == 108); // BITMAPV4INFOHEADER
static assert (DIBHeader!(Ver.V5).sizeof == 124); // BITMAPV5INFOHEADER

struct WinBitfieldsMasks(Ver V) if (V >= Ver.V2)
{
align(1):
	uint redBitMask;
	uint greenBitMask;
	uint blueBitMask;

	static if (V >= Ver.V3)
	{
		uint alphaMask;
	}

	WBFM opCast(WBFM)() if (is(WBFM == WinBitfieldsMasks!(Ver.V5)))
	{
		static if (V >= Ver.V3)
			return WBFM(redBitMask, greenBitMask, blueBitMask, alphaMask);
		else
			return WBFM(redBitMask, greenBitMask, blueBitMask);
	}
}

align(1) struct WinPaletteElement(Ver V)
{
	ubyte blue;
	ubyte green;
	ubyte red;

	static if (V >= Ver.V1)
	{
		ubyte alpha;
	}

	T opCast(T)() const if (is(T == uint))
	{
		static if (V == Ver.V0)
			return blue << 0 | green << 8 | red << 16;
		else
			return blue << 0 | green << 8 | red << 16 | alpha << 24;
	}
}

private alias WPE0 = WinPaletteElement!(Ver.V0);
private alias WPE1 = WinPaletteElement!(Ver.V1);
static assert (      WPE0.sizeof     == 3);
static assert (      WPE1.sizeof     == 4);
static assert (Type!(WPE0[2]).sizeof == 6);
static assert (Type!(WPE1[2]).sizeof == 8);

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

unittest
{
	// Example 1 from http://en.wikipedia.org/wiki/BMP_file_format

	ubyte[] arr =
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

	UntypedBuffer testImageRawData;

	testImageRawData.write(arr);

	const BMPImage!uint info = loadBmp!(uint, LoadHeaderOnly.no)(testImageRawData);

	assert (info.file_header.signature == "BM");
	assert (info.file_header.fileSize == 70);
	assert (info.file_header.offsetToPixelArray == 54);

	assert (info.dib_header.version_ == 40);
	assert (info.dib_header.width == 2);
	assert (info.dib_header.height == 2);
	assert (info.dib_header.colorPlanesCount == 1);
	assert (info.dib_header.bpp == 24);
	assert (info.dib_header.compression == Compression.BI_RGB);
	assert (info.dib_header.sizeOfPixelArray == 16);
	assert (info.dib_header.pixelsPerMeterX == 2835);
	assert (info.dib_header.pixelsPerMeterY == 2835);
	assert (info.dib_header.colorsUsed == 0);
	assert (info.dib_header.colorsImportant == 0);

	alias Pixel = WinPaletteElement!(Ver.V0);
	assert (Pixel.sizeof * 8 == info.dib_header.bpp);

	assert(info.pixels[0, 0] == Pixel(255, 0, 0).to!uint);
	assert(info.pixels[1, 0] == Pixel(0, 255, 0).to!uint);
	assert(info.pixels[0, 1] == Pixel(0, 0, 255).to!uint);
	assert(info.pixels[1, 1] == Pixel(255, 255, 255).to!uint);
}

unittest
{
	// Example 2 from http://en.wikipedia.org/wiki/BMP_file_format

	ubyte[] arr =
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

	UntypedBuffer testImageRawData;

	testImageRawData.write(arr);

	const BMPImage!uint info = loadBmp!(uint, LoadHeaderOnly.no)(testImageRawData);

	assert (info.file_header.signature == "BM");
	assert (info.file_header.fileSize == 154);
	assert (info.file_header.offsetToPixelArray == 122);

	assert (info.dib_header.version_ == 108);
	assert (info.dib_header.width == 4);
	assert (info.dib_header.height == 2);
	assert (info.dib_header.colorPlanesCount == 1);
	assert (info.dib_header.bpp == 32);
	assert (info.dib_header.compression == Compression.BI_BITFIELDS);
	assert (info.dib_header.sizeOfPixelArray == 32);
	assert (info.dib_header.pixelsPerMeterX == 2835);
	assert (info.dib_header.pixelsPerMeterY == 2835);
	assert (info.dib_header.colorsUsed == 0);
	assert (info.dib_header.colorsImportant == 0);
	assert (info.dib_header.bitMasks == WinBitfieldsMasks!(Ver.V5)(0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000));

	assert (info.dib_header.colorSpaceType == LogicalColorSpace.LCS_WINDOWS_COLOR_SPACE);
	assert (info.dib_header.colorSpaceEndpoints == CIE_XYZ_Triple.init);
	assert (info.dib_header.gammaRed == 0);
	assert (info.dib_header.gammaGreen == 0);
	assert (info.dib_header.gammaBlue == 0);

	alias Pixel = WinPaletteElement!(Ver.V4);
	assert (Pixel.sizeof * 8 == info.dib_header.bpp);

	assert(info.pixels[0, 0] == Pixel(255,   0,   0, 255).to!uint);
	assert(info.pixels[1, 0] == Pixel(  0, 255,   0, 255).to!uint);
	assert(info.pixels[2, 0] == Pixel(  0,   0, 255, 255).to!uint);
	assert(info.pixels[3, 0] == Pixel(255, 255, 255, 255).to!uint);
	assert(info.pixels[0, 1] == Pixel(255,   0,   0, 127).to!uint);
	assert(info.pixels[1, 1] == Pixel(  0, 255,   0, 127).to!uint);
	assert(info.pixels[2, 1] == Pixel(  0,   0, 255, 127).to!uint);
	assert(info.pixels[3, 1] == Pixel(255, 255, 255, 127).to!uint);
}
