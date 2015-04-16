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

	pure nothrow:

	@trusted
	void alloc(size_t width, size_t height)
	{
		this.width = width;
		this.height = height;
		if (pixels.length < width * height)
			pixels = cast(C[])new void[C.sizeof * width * height];
	}

	@trusted
	auto ref inout(C) opIndex(size_t x, size_t y) inout
	{
		return scanline(y)[x];
	}


	@trusted
	inout(C)[] scanline(size_t y) inout
	{
		assert(y >= 0 && y < height);
		return pixels[width * y .. width * (y + 1)];
	}

	@trusted
	@property bool empty() const
	{
		return pixels.ptr is null || pixels.length == 0;
	}
}
