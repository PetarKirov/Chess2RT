module gui.sdl2gui;

import gfm.opengl.opengl;
import gfm.sdl2, std.experimental.logger : sharedLog, log;
import std.conv : to;
import imageio.image, util.prop;

//Default SDL2 GUI
struct SDL2Gui
{
	uint width, height;

	mixin property!(SDL2, "sdl2", Access.ReadOnly);
	mixin property!(SDL2Window, "window", Access.ReadOnly);
	mixin property!(OpenGL, "gl", Access.ReadOnly);
	mixin property!(SDL2Renderer, "renderer", Access.ReadOnly);
	mixin property!(SDL2Surface, "surface", Access.ReadOnly);
	mixin property!(SDL2Texture, "texture", Access.ReadOnly);

	void acquire(uint width, uint height, string title)
	{
		_sdl2 = new SDL2(sharedLog, SharedLibVersion(2, 0, 0));

		_gl = new OpenGL(sharedLog);
		
		import derelict.sdl2.types;
		
		sdl2.subSystemInit(SDL_INIT_VIDEO);
		sdl2.subSystemInit(SDL_INIT_EVENTS);

		_window = new SDL2Window(sdl2, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
			width, height,
			SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE | 
			SDL_WINDOW_INPUT_FOCUS | SDL_WINDOW_MOUSE_FOCUS |
			SDL_WINDOW_OPENGL);

		// Set our OpenGL version.
		// SDL_GL_CONTEXT_CORE gives us only the newer version, deprecated functions are disabled
		//SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
		
		// 3.2 is part of the modern versions of OpenGL, but most video cards whould be able to run it
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
		
		// Turn on double buffering with a 24bit Z buffer.
		// You may need to change this to 16 or 32 for your system
		SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

		_gl.reload();

		_window.setTitle(title);
//		_renderer = new SDL2Renderer(window, SDL_RENDERER_SOFTWARE);
//		_surface = new SDL2Surface(sdl2, width, height, 32,
//								  0x00FF0000,
//								  0x0000FF00,
//								  0x000000FF,
//								  0xFF000000);
//
//		_texture = new SDL2Texture(renderer,
//								  SDL_PIXELFORMAT_ARGB8888,
//								  SDL_TEXTUREACCESS_STREAMING,
//								  surface.width, surface.height);
//		this.width = width;
//		this.height = height;
//
//		renderer.setColor(0, 0, 0, 255);
//		renderer.clear();
	}

	void draw(SRC)(auto ref SRC image)
	{
//		uint* pixels = cast(uint*)surface.pixels;
//
//		int rs = surface.pixelFormat.Rshift;
//		int gs = surface.pixelFormat.Gshift;
//		int bs = surface.pixelFormat.Bshift;
//
//		foreach (y; 0 .. surface.height)
//			foreach (x; 0 .. surface.width)
//				pixels[y * surface.width + x] = to!uint(image[x, y]);
//
//		//TODO: Check this cast below.
//		texture.updateTexture(surface.pixels, cast(int)surface.pitch);
//		renderer.copy(texture, 0, 0);
//		renderer.present();
	}

	void release()
	{
		log("Attempting to close SDL2 resources.");
		texture.destroy();
		surface.destroy();
		renderer.destroy();
		window.destroy();
		sdl2.destroy();
	}

	~this()
	{
		log("At ~SDL2Gui()");
		this.release();
	}
}

void testGUIMain()
{
	import std.algorithm, std.range, std.math;

	uint w = 640, h = 480;

	auto gui = SDL2Gui();
	gui.acquire(w, h, "Pulsing circle");

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
