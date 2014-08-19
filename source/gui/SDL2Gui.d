module gui.sdl2gui;

import std.logger;
import gfm.sdl2, ae.utils.graphics.image;

//Default SDL2 GUI
struct SDL2Gui
{
	private
	{
		SDL2 _sdl2;
		Window _window;
		SDL2Renderer _renderer;
		SDL2Surface surface;
		SDL2Texture _texture;
		Logger _log;

		size_t _width, _height;
	}

	SDL2 sdl2() { return _sdl2; }

	@property
	size_t width() { return this._width; }

	@property
	void width(size_t newValue) { this._width = newValue; }

	@property
	size_t height() { return this._height; }
	
	@property
	void height(size_t newValue) { this._height = newValue; }


	this(size_t width, size_t height, string title, Logger log)
	{
		_log = log;
		_sdl2 = new SDL2(_log);
		_window = new Window(_sdl2, width, height, title);
		_renderer = new SDL2Renderer(_window, SDL_RENDERER_SOFTWARE);
		surface = new SDL2Surface(_sdl2, width, height, 32,
		                               0x00FF0000,
		                               0x0000FF00,
		                               0x000000FF,
		                               0xFF000000);

		_texture = new SDL2Texture(_renderer,
		                           SDL_PIXELFORMAT_ARGB8888,
		                           SDL_TEXTUREACCESS_STREAMING,
		                           surface.width, surface.height);
		this._width = width;
		this._height = height;
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

		SDL_UpdateTexture(_texture.handle(), null, surface.pixels, surface.pitch);
		_renderer.clear();
		_renderer.copy(_texture);
		_renderer.present();
	}

	private void close()
	{
		_log.log("Attempting to close SDL2 resources.");
		_texture.close();
		surface.close();
		_renderer.close();
		_window.close();
		_sdl2.close();
	}

	~this()
	{	
		_log.log("At ~SDL2Gui()");
		this.close();
	}
}

// Default SDL2 Window
class Window : SDL2Window
{
	this(SDL2 sdl2, int width, int height, string title)
	{
		super(sdl2, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
		      width, height,
		      SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE | SDL_WINDOW_INPUT_FOCUS | SDL_WINDOW_MOUSE_FOCUS);

		super.setTitle(title);
	}
}

void testGUIMain()
{
	import std.algorithm, std.range, std.math;
	import ae.utils.graphics.view;
	
	size_t w = 640, h = 480;

	auto gui = SDL2Gui(w, h, "Pulsing circle", new StdIOLogger(LogLevel.trace));
	
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
		
	})(w, h);
	
	gui.draw(image);
	
	double time = 0;
	while(!gui.sdl2().keyboard().isPressed(SDLK_ESCAPE))
	{
		gui.sdl2().processEvents();
		
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
