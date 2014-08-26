module gui.guidemo;

import gui.sdl2gui;
import gui.guibase; import std.math;

class GuiDemo : GuiBase!uint
{
	this(size_t width, size_t height, string windowTitle)
	{
		super(width, height, windowTitle);
	}

	override void render()
	{
		if (rendered) return;
		
		drawCircle();
		
		rendered = true;
	}

private:
	bool rendered;

	/// Draws a [green, blue] radial gradient on a red background
	void drawCircle()
	{
		auto w = gui.width, h = gui.height;
		
		double radius = 50.0;		
		
		double cx = w / 2;
		double cy = h / 2;
		
		foreach (int y; 0 .. toInt(h))
			foreach (int x; 0 .. toInt(w))
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
}


