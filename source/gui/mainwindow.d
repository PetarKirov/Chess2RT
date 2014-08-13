module gui.mainwindow;

import std.conv, std.math, std.typecons;

import std.logger;
import gfm.core, gfm.math, gfm.sdl2, ae.utils.graphics.image, ae.utils.graphics.view;

import std.algorithm, std.range;



void run()
{	
	size_t w = 640, h = 480;

	//auto sdl2 = scoped!SDL2(null);
	auto gui = scoped!GUI(w, h, "Chess 2");

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

class GUI
{
	private
	{
		SDL2 _sdl2;
		Window _window;
		SDL2Renderer _renderer;
		SDL2Surface surface;
		SDL2Texture _texture;
	}

	SDL2 sdl2() { return _sdl2; }

	this(size_t width, size_t height, string title, Logger log = null)
	{
		_sdl2 = new SDL2(log);
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
	}

	void draw(SRC)(auto ref SRC image) if (isView!SRC)
	{
		ubyte* pixels = surface.pixels;
		
		int rs = surface.pixelFormat.Rshift;
		int gs = surface.pixelFormat.Gshift;
		int bs = surface.pixelFormat.Bshift;

		foreach (y; 0 .. surface.height)
			foreach (x; 0 .. surface.width)
				(cast(uint*)pixels)[y * surface.width + x] = to!uint(image[x, y]);

		SDL_UpdateTexture(_texture.handle(), null, surface.pixels, surface.pitch);
		_renderer.clear();
		_renderer.copy(_texture);
		_renderer.present();
	}

	void close()
	{
		_texture.close();
		surface.close();
		_renderer.close();
		_window.close();
		_sdl2.close();
	}

	~this()
	{
		close();
	}
}

class Window : SDL2Window
{
	public
	{
		this(SDL2 sdl2, int width, int height, string title)
		{
			super(sdl2, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
			      width, height,
			      SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE | SDL_WINDOW_INPUT_FOCUS | SDL_WINDOW_MOUSE_FOCUS);

			super.setTitle(title);

			_closed = false;
		}
		
		override void onClose()
		{
			_closed = true;
		}
	}
	
	private
	{
		bool _closed;
	}
	
}