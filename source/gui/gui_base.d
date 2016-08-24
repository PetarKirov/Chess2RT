module gui.guibase;

import std.experimental.logger : log;
import std.variant : Variant;
import gui.appsceleton, gui.sdl2gui;
import imageio.bmp : Image;

/// Base class based on SDL2 for GUI.
/// 
/// Params:
///		C =	The type of the pixel color.
abstract class GuiBase(C) : AppSceleton
{
	protected
	{
		SDL2Gui gui;
		Image!C screen;
		Variant init_args;
	}

	this(Variant init_settings)
	{
		this.init_args = init_settings;
	}
	
	~this()
	{
		log("At ~GuiBase()");
	}

	static struct InitSettings
	{
		uint width, height;
		string windowTitle;
	}

	override void acquireResources()
	{
		if (init_args.peek!InitSettings is null)
			return;

		auto params = init_args.get!InitSettings;

		gui.acquire(params.width, params.height, params.windowTitle);

		screen.alloc(params.width, params.height);
	}

	override void releaseResources()
	{
		gui.release();
	}

	override bool handleInput()
	{
		import gfm.sdl2 : SDLK_ESCAPE;
		
		return !gui.sdl2.keyboard().isPressed(SDLK_ESCAPE) &&
			!gui.sdl2.wasQuitRequested();
	}
	
	override void update()
	{
		gui.sdl2.processEvents();
	}
	
	override void render()
	{
	}
	
	final override void display()
	{
		gui.draw(screen);
	}
}
