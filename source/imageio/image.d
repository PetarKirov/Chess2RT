module imageio.image;

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

	@trusted pure nothrow:

	void alloc(size_t width, size_t height)
	{
		import std.array : uninitializedArray;

		this.width = width;
		this.height = height;

		if (this.pixels.length < width * height)
			this.pixels = uninitializedArray!(C[])(width * height);
	}

	auto ref inout(C) opIndex(size_t x, size_t y) inout
	{
		return scanline(y)[x];
	}

	inout(C)[] scanline(size_t y) inout
	{
		assert(y >= 0 && y < height);
		return pixels[width * y .. width * (y + 1)];
	}

	@property bool empty() const
	{
		return pixels.ptr is null || pixels.length == 0;
	}
}
