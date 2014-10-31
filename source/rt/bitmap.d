module rt.bitmap;

import std.math, std.path, std.string;
import util.prop;
import rt.color, imageio.bmp;
import std.exception, std.string, rt.exception;

/// Represents a bitmap (2d array of colors), e.g. a image
/// supports loading/saving to BMP and EXR
struct Bitmap
{
	Image!Color data;

	@property const @nogc
	{
		uint width() { return data.width; }
		uint height() { return data.height; }
	}

	/// Gets the pixel at coordinates (x, y).
	/// Returns red if (x, y) is outside of the image.
	inout(Color) getPixel(uint x, uint y) inout
	{
		if (isInvalidPos(x, y))
			return NamedColors.red;
		else
			return data[x, y];
	}

	/// Sets the pixel at coordinates (x, y).
	void setPixel(int x, int y, in Color col)
	{
		if (isInvalidPos(x, y)) return;
		data[x, y] = col;
	}

	void generateEmptyImage(uint width, uint height) { data.alloc(width, height); }

	~this() { }

	@disable
	void freeMem() { data.alloc(0, 0); }

	private bool isInvalidPos(uint x, uint y) const @nogc
	{
		return data.pixels.length == 0 ||
			!data.width ||
			!data.height ||
			x >= data.width ||
			y >= data.height;
	}

	/// Gets a bilinear-filtered pixel from float coords (x, y).
	/// The coordinates wrap when near the edges.
	inout(Color) getFilteredPixel(float x, float y) inout @nogc
	{
		if (isInvalidPos(cast(uint)x, cast(uint)y))
			return NamedColors.red;

		int tx = cast(int)floor(x);
		int ty = cast(int)floor(y);
		int tx_next = (tx + 1) % data.width;
		int ty_next = (ty + 1) % data.height;
		float p = x - tx;
		float q = y - ty;
		return data[tx		, ty	] * ((1.0f - p) * (1.0f - q))
			+ data[tx_next	, ty	] * (        p  * (1.0f - q))
			+ data[tx	  	, ty_next] * ((1.0f - p) *         q )
			+ data[tx_next	, ty_next] * (        p  *         q );
	}

	/// Loads an image.
	/// The format is detected from extension.
	void loadImage(string filename)
	{
		switch (filename.extension.toLower)
		{
			case ".bmp": loadBmp(data, filename); break;
			case ".exr": loadExr(this, filename); break;
			default: throw new UnknownImageTypeException();
		}
	}

	/// Save the bitmap to an image.
	/// The format is detected from extension.
	void saveImage(string filename)
	{
		switch (filename.extension.toLower)
		{
			case ".bmp": saveBmp(this, filename); break;
			case ".exr": saveExr(this, filename); break;
			default: throw new UnknownImageTypeException();
		}
	}

	/// Loads an image from a BMP file.
	void loadBMP(string filename)
	{
		assert(0, "Not implemented!");
	}

	/// Loads an EXR file.
	void loadEXR(string filename)
	{
		loadExr(this, filename);
	}

	/// Saves the image to a BMP file (with clamping, etc). Uses the sRGB colorspace.
	void saveBMP(string filename)
	{
		saveBmp(this, filename);
	}
	
	/// Saves the image into the EXR format, preserving the dynamic range, using Half for storage. Note that
	/// in contrast with saveBMP(), it does not use gamma-compression on saving.
	void saveEXR(string filename)
	{
		saveExr(this, filename);
	}

	void remapRGB(scope float delegate(float) remapFn)
	{
		foreach (ref pixel; data.pixels)
		{
			pixel.r = remapFn(pixel.r);
			pixel.g = remapFn(pixel.g);
			pixel.b = remapFn(pixel.b);
		}
	}

	/// assuming the pixel data is in sRGB, decompress to linear RGB values
	void decompressGamma_sRGB()
	{
		remapRGB((float x) {
			if (x == 0) return 0.0f;
			if (x == 1) return 1.0f;
			if (x <= 0.04045f)
				return x / 12.92f;
			else
				return ((x + 0.055f) / 1.055f) ^^ 2.4f;
		});
	}

	/// as above, but assume a specific gamma value
	void decompressGamma(float gamma)
	{
		remapRGB((float x) {
			if (x == 0) return 0.0f;
			if (x == 1) return 1.0f;
			return x ^^ gamma;
		});
	}

	/// differentiate image (red = dx, green = dy, blue = 0)
	void differentiate()
	{
		Bitmap result;
		result.generateEmptyImage(width, height);
		
		foreach (y; 0 .. height)
		foreach (x; 0 .. width) {
			float me = getPixel(x, y).intensity();
			float right = getPixel((x + 1) % width, y).intensity();
			float bottom = getPixel(x, (y + 1) % height).intensity();
			
			result.setPixel(x, y, Color(me - right, me - bottom, 0.0f));
		}

		this = result;
	}

	void toString(scope void delegate(const(char)[]) sink) const
	{
		import std.conv;

		sink("img[");
		sink(to!string(width()));
		sink("x");
		sink(to!string(height()));
		sink("]");
	}
}

private:

void saveBmp(Bitmap bmp, string filename)
{
	throw new NotImplementedException();
}

void loadExr(Bitmap bmp, string filename)
{
	throw new NotImplementedException();
}

void saveExr(Bitmap bmp, string filename)
{
	throw new NotImplementedException();
}
