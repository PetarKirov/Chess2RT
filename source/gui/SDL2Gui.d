module gui.sdl2gui;

import std.experimental.logger;
import gfm.sdl2, ae.utils.graphics.image;
import util.prop;

//For x64 compatability
//Very questionable!!!
int toInt(size_t val)
{
	return to!int(val);
}


//Default SDL2 GUI
struct SDL2Gui
{
	size_t width, height;

	mixin property!(SDL2, "sdl2", Access.ReadOnly);
	mixin property!(Window, "window", Access.ReadOnly);
	mixin property!(SDL2Renderer, "renderer", Access.ReadOnly);
	mixin property!(SDL2Surface, "surface", Access.ReadOnly);
	mixin property!(SDL2Texture, "texture", Access.ReadOnly);
	mixin property!(Logger, "log", Access.ReadOnly);	

	this(size_t width, size_t height, string title, Logger log)
	{
		init(width, height, title, log);
	}

	void init(size_t width, size_t height, string title, Logger log)
	{
		_log = log;
		_sdl2 = new SDL2(log);
		_window = new Window(sdl2, width, height, title);
		_renderer = new SDL2Renderer(window, SDL_RENDERER_SOFTWARE);
		_surface = new SDL2Surface(sdl2, toInt(width), toInt(height), 32,
								  0x00FF0000,
								  0x0000FF00,
								  0x000000FF,
								  0xFF000000);

		_texture = new SDL2Texture(renderer,
								  SDL_PIXELFORMAT_ARGB8888,
								  SDL_TEXTUREACCESS_STREAMING,
								  surface.width, surface.height);
		this.width = width;
		this.height = height;

		renderer.setColor(0, 0, 0, 255);
		renderer.clear();
	}

	void draw(SRC)(auto ref SRC image) if (isView!SRC)
	{
		uint* pixels = cast(uint*)surface.pixels;
		
		int rs = surface.pixelFormat.Rshift;
		int gs = surface.pixelFormat.Gshift;
		int bs = surface.pixelFormat.Bshift;

		foreach (y; 0 .. surface.height)
			foreach (x; 0 .. surface.width)
				pixels[y * surface.width + x] = to!uint(image[x, y]);

		texture.updateTexture(surface.pixels, toInt(surface.pitch));
		renderer.copy(texture, 0, 0);
		renderer.present();
	}

	private void close()
	{
		log.log("Attempting to close SDL2 resources.");
		texture.close();
		surface.close();
		renderer.close();
		window.close();
		sdl2.close();
	}

	~this()
	{	
		log.log("At ~SDL2Gui()");
		this.close();
	}
}

// Default SDL2 Window
class Window : SDL2Window
{
	this(SDL2 sdl2, size_t width, size_t height, string title)
	{
		super(sdl2, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
		      toInt(width), toInt(height),
		      SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE | SDL_WINDOW_INPUT_FOCUS | SDL_WINDOW_MOUSE_FOCUS);

		super.setTitle(title);
	}
}

void testGUIMain()
{
	import std.algorithm, std.range, std.math;
	import ae.utils.graphics.view;
	
	size_t w = 640, h = 480;

	auto gui = SDL2Gui(w, h, "Pulsing circle", stdlog);
	
	double radius = 50.0;
	
	double cx = w / 2;
	double cy = h / 2;
	
	double vx = 1;
	double vy = 1;
	
	auto image = procedural!((x, y) { 
		double xd = x - cx;
		double yd = y - cy;
		
		auto dist = sqrt(xd^^2 + yd^^2);
		if (dist < radius)
		{
			return ((cast(int)(dist / radius * 255)) << 8) + 0x0000FF;
		}
		else
			return 0xFF0000;
		
	})(toInt(w), toInt(h));
	
	gui.draw(image);
	
	double time = 0;
	while(!gui.sdl2.keyboard().isPressed(SDLK_ESCAPE))
	{
		gui.sdl2.processEvents();
		
		gui.draw(image);
		
		auto sinTick = (sin(time) * 0.5 + 0.5);
		radius = 50 * sinTick;
		
		if (cx + radius > w || cx - radius < w) vx = -vx;
		if (cy + radius > h || cy - radius < h) vy = -vy;
		
		time += 0.10;
		cx += vx;
		cy += vy;
	}
}
