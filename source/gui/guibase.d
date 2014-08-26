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
		Image!C screen;
		Logger log;
	}

	this(Logger log)
	{
		this.log = log;
	}
	
	this(size_t width, size_t height, string windowTitle)
	{
		log = new StdIOLogger(LogLevel.trace);
		initGui(width, height, windowTitle);
	}

	protected void initGui(size_t width, size_t height, string windowTitle)
	{
		gui.init(width, height, windowTitle, log);
	}
	
	~this()
	{
		log.log("At ~GuiBase()");
	}

	/// All overriding classes should call super.init() first!
	override void init()
	{
		screen.size(toInt(gui.width), toInt(gui.height));
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
	
	override bool handleInput()
	{
		import gfm.sdl2;
		
		return !gui.sdl2.keyboard().isPressed(SDLK_ESCAPE);
	}
}