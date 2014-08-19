module gui.guibase;

import std.logger;
import ae.utils.graphics.image;

import gui.appsceleton, gui.sdl2gui;

//C = Color type
abstract class GuiBase(C) : AppSceleton
{
	protected
	{
		SDL2Gui gui;
		Image!C image;
		StdIOLogger log;
	}
	
	this(size_t width, size_t height, string windowTitle)
	{
		log = new StdIOLogger(LogLevel.trace);
		gui = SDL2Gui(width, height, windowTitle, log);
	}
	
	~this()
	{
		log.log("At ~GuiBase()");
	}

	/// All overriding classes should call super.init() first!
	override void init()
	{
		image.size(gui.width, gui.height);
	}
	
	override void update()
	{
		gui.sdl2().processEvents();
	}
	
	override void render()
	{
	}
	
	final override void display()
	{
		gui.draw(image);
	}
	
	override bool handleInput()
	{
		import gfm.sdl2;
		
		return !gui.sdl2().keyboard().isPressed(SDLK_ESCAPE);
	}
}