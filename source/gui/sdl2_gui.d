module gui.sdl2gui;

import gfm.sdl2, std.experimental.logger;
import std.conv : to;
import imageio.image, util.prop;

//Default SDL2 GUI
struct SDL2Gui
{
	uint width, height;

	mixin property!(SDL2, "sdl2", Access.ReadOnly);
	mixin property!(SDL2Window, "window", Access.ReadOnly);
	mixin property!(SDL2Renderer, "renderer", Access.ReadOnly);
	mixin property!(SDL2Surface, "surface", Access.ReadOnly);
	mixin property!(SDL2Texture, "texture", Access.ReadOnly);
	mixin property!(Logger, "log", Access.ReadOnly);	

	this(uint width, uint height, string title, Logger log)
	{
		init(width, height, title, log);
	}

	void init(uint width, uint height, string title, Logger log)
	{
		_log = log;
		_sdl2 = new SDL2(log, SharedLibVersion(2, 0, 0));
		_window = new SDL2Window(sdl2, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
								width, height,
								SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE | SDL_WINDOW_INPUT_FOCUS | SDL_WINDOW_MOUSE_FOCUS);
		_window.setTitle(title);
		_renderer = new SDL2Renderer(window, SDL_RENDERER_SOFTWARE);
		_surface = new SDL2Surface(sdl2, width, height, 32,
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

	void draw(SRC)(auto ref SRC image)
	{
		uint* pixels = cast(uint*)surface.pixels;
		
		int rs = surface.pixelFormat.Rshift;
		int gs = surface.pixelFormat.Gshift;
		int bs = surface.pixelFormat.Bshift;

		foreach (y; 0 .. surface.height)
			foreach (x; 0 .. surface.width)
				pixels[y * surface.width + x] = to!uint(image[x, y]);

		//TODO: Check this cast below.
		texture.updateTexture(surface.pixels, cast(int)surface.pitch);
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

void testGUIMain()
{
	import std.algorithm, std.range, std.math;
	
	uint w = 640, h = 480;

	auto gui = SDL2Gui(w, h, "Pulsing circle", sharedLog);
	
	double radius = 50.0;
	
	double cx = w / 2;
	double cy = h / 2;
	
	double vx = 1;
	double vy = 1;

	struct ProcImage
	{
		auto opIndex(size_t x, size_t y) {
			double xd = x - cx;
			double yd = y - cy;

			auto dist = sqrt(xd^^2 + yd^^2);
			if (dist < radius)
			{
				return ((cast(int)(dist / radius * 255)) << 8) + 0x0000FF;
			}
			else
				return 0xFF0000;
		}
	}
	
	gui.draw(ProcImage());
	
	double time = 0;
	while(!gui.sdl2.keyboard().isPressed(SDLK_ESCAPE))
	{
		gui.sdl2.processEvents();
		
		gui.draw(ProcImage());
		
		auto sinTick = (sin(time) * 0.5 + 0.5);
		radius = 50 * sinTick;
		
		if (cx + radius > w || cx - radius < w) vx = -vx;
		if (cy + radius > h || cy - radius < h) vy = -vy;
		
		time += 0.10;
		cx += vx;
		cy += vy;
	}
}
