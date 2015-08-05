module gui.guidemo;

import std.math;
import gui.sdl2gui, gui.guibase;
import imageio.image;

class GuiDemo : GuiBase!uint
{
	this(uint width, uint height, string windowTitle)
	{
		super(width, height, windowTitle);
	}

	override void render()
	{
		if (rendered) return;
		
		drawImage();
		
		rendered = true;
	}

private:
	bool rendered;

	/// Draws a [green, blue] radial gradient on a red background
	void drawCircle()
	{
		uint w = gui.width, h = gui.height;
		
		double radius = 50.0;		
		
		double cx = w / 2;
		double cy = h / 2;
		
		foreach (int y; 0 .. h)
			foreach (int x; 0 .. w)
		{
			double dx = x - cx;
			double dy = y - cy;
			auto dist = sqrt(dx^^2 + dy^^2);
			
			if (dist < radius)
				screen[x, y] = cast(uint)(dist / radius * 255) + 0x00FF00;
			else
				screen[x, y] = 0xFF0000;
		}
	}

	void drawImage()
	{
		import imageio.bmp, imageio.buffer : UntypedBuffer;
		import std.file : read;

		string imgPath = "data/texture/zaphod.bmp";
		Image!ARGB pixels = imgPath.read().UntypedBuffer.loadBmp!ARGB;

		pixels.cropCopyTo(screen);
	}
}

void cropCopyTo(Img1, Img2)(Img1 source, Img2 dest)
{
	foreach (y; 0 .. dest.h)
		foreach (x; 0 .. dest.w)
			if (x < source.w && y < source.h)
				dest[x, y] = cast(typeof(dest[0, 0]))source[x, y];
			else
				dest[x, y] = 0;
}

void scaleCopyTo(Img1, Img2)(Img1 source, Img2 dest)
{
	foreach (y; 0 .. dest.h)
		foreach (x; 0 .. dest.w)
		{
			// TODO...
		}
}

struct ARGB
{
	union
	{
		uint value;
		struct { ubyte b, g, r, a; }
	}

pure:

	this (uint hexColor) { this.value = hexColor; }
	this (ubyte r_, ubyte g_, ubyte b_) { r = r_; g = g_; b = b_;}
	T opCast(T)() if (is(T == uint)) { return value; }
}

unittest
{
	auto alpha = ARGB(0xFF000000);
	auto red = ARGB(0x00FF0000);
	auto green = ARGB(0x0000FF00);
	auto blue = ARGB(0x000000FF);

	assert(alpha.a == 255);
	assert(red.r == 255);
	assert(green.g == 255);
	assert(blue.b == 255);
}