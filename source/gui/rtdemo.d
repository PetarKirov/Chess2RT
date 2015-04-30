module gui.rtdemo;

import core.atomic : atomicOp;
import std.stdio : writefln;
import std.datetime : benchmark, Clock;
import std.experimental.logger;
import gui.guibase, rt.renderer, rt.scene, rt.sceneloader, rt.color;

import std.concurrency;

string getNewImageFileName()
{
	import std.format : format;
	import std.array : replace;

	auto time = Clock.currTime()
					.toISOExtString()
					.replace(":", "_");

	return format("output/img_%s.bmp", time);
}

class RTDemo : GuiBase!Color
{
	string sceneFilePath;
	Scene scene;
	Renderer renderer;
	shared bool needsRendering;
	shared bool isRendering;
	shared byte[] tasksCount = new shared byte[2];
	Tid renderThread;

	this(string sceneFilePath_, Logger log = stdlog)
	{
		super(log);
		this.sceneFilePath = sceneFilePath_;
	}

	~this()
	{
		log.log("At ~RTDemo");	
	}

	override void init()
	{
		log.log("Loading scene: " ~ sceneFilePath);

		scene = parseSceneFromFile(sceneFilePath);

		super.initGui(scene.settings.frameWidth,
					  scene.settings.frameHeight,
					  r"RT Demo ¯\_(ツ)_/¯");

		//Set the screen size according to the settings in the scene file
		screen.alloc(scene.settings.frameWidth,
					scene.settings.frameHeight);

		this.renderer = new Renderer(scene, screen);
		this.needsRendering = true;
		
		debug printDebugInfo();
	}

	override void render()
	{
		//No need for re-rendering - nothing changes in the main loop.
		if (!needsRendering || isRendering)
			return;

		log.log("Rendering!!!");

		isRendering = true;

		spawn((shared RTDemo this_s)
			{
				auto this_ = cast(RTDemo)this_s;					
				this_.scene.beginFrame();
				this_.renderer.renderRT();
				this_s.isRendering = false;
				this_s.needsRendering = false;
			}, cast(shared RTDemo)this,);
	}

	override bool handleInput()
	{
		import core.atomic : atomicOp;
		import std.parallelism : task, taskPool;
		import derelict.sdl2.types;

		if (scene.settings.interactive)
			move();

		auto mouse = gui.sdl2.mouse();
		auto kbd = gui.sdl2.keyboard();

		if (mouse.isButtonPressed(SDL_BUTTON_LMASK))
			printMouse(mouse.x, mouse.y);

		if (kbd.isPressed(SDLK_F12))
			takeScreenshot();

		return super.handleInput;
	}
	
	void takeScreenshot()
	{
		import rt.bitmap;
		import std.file : mkdir, exists;

		if (!exists("output"))
			mkdir("output");

		auto bitmap = const Bitmap(this.screen);
		bitmap.saveImage(getNewImageFileName());
	}

	private void printMouse(int x, int y)
	{
		auto color = renderer.renderPixelNoAA(x, y);
		
		auto result = renderer.lastTracingResult;
		
		writefln("Mouse click at: (%s %s)", x, y);
		writefln("  Raytrace[start = %s, dir = %s]", result.ray.orig, result.ray.dir);
		
		if (result.hitLight)
			writefln("    Hit light with color: ", result.hitLightColor);
		
		else if(!result.closestNode)
			writefln("    Hit environment: ", scene.environment.getEnvironment(result.ray.dir));
		
		else
		{
			writefln("    Hit %s at distance %s", typeid(result.closestNode.geom), result.data.dist);
			writefln("      Color: %s", color);
			writefln("      Intersection point: %s", result.data.p);
			writefln("      Normal:             %s", result.data.normal);
			writefln("      UV coods:           %s, %s", result.data.u, result.data.v);
		}
		
		writefln("Raytracing completed!\n");
	}

	private void move()
	{
		// Ignore input events while rendering because we are already rendering.
		// Perhaps we can save the last input event and handle it
		// after we finish rendering.
		if (needsRendering)
			return;

		import derelict.sdl2.types;

		enum dMove = 32, dRotate = 4;

		auto controls = 
		[
			Controls ([SDLK_RIGHT, SDLK_LCTRL], 0, 0, 0, 0, dRotate),
			Controls ([SDLK_RIGHT, SDLK_LSHIFT], 0, 0, 0, -dRotate),
			Controls ([SDLK_RIGHT], dMove),

			Controls ([SDLK_LEFT, SDLK_LCTRL], 0, 0, 0, 0, -dRotate),
			Controls ([SDLK_LEFT, SDLK_LSHIFT], 0, 0, 0, dRotate),
			Controls ([SDLK_LEFT], -dMove),

			Controls ([SDLK_DOWN, SDLK_LCTRL], 0, -dMove),
			Controls ([SDLK_DOWN, SDLK_LSHIFT], 0, 0, 0, 0, 0, -dRotate),
			Controls ([SDLK_DOWN], 0, 0, -dMove),

			Controls ([SDLK_UP, SDLK_LCTRL], 0, dMove),
			Controls ([SDLK_UP, SDLK_LSHIFT], 0, 0, 0, 0, 0, dRotate),
			Controls ([SDLK_UP], 0, 0, dMove),
		];

		move_impl(controls);
	}

	/// Encapsulates a camera control keys binding.
	private static struct Controls
	{
		int[] keyCodes;
		double dx = 0.0, dy = 0.0, dz = 0.0;
		double dYaw = 0.0, dRoll = 0.0, dPitch = 0.0;

		/// Params:
		/// 	keyCodes =	array of SDL2 key codes to test
		/// 	dx =		left/right movement
		/// 	dy =		up/down movement
		/// 	dz =		forward/backword movement
		/// 	dYaw =		left/right rotation [0..360]
		/// 	dRoll =		roll rotation [-180..180]
		/// 	dPitch =	up/down rotation [-90..90]
		this(int[] keyCodes, double dx = 0.0, double dy = 0.0, double dz = 0.0,
			double dYaw = 0.0, double dRoll = 0.0, double dPitch = 0.0)
		{
			this.keyCodes = keyCodes;
			this.dx = dx;
			this.dy = dy;
			this.dz = dz;
			this.dYaw = dYaw;
			this.dRoll = dRoll;
			this.dPitch = dPitch;
		}
	}

	/// Moves and/or rotates the camera according to the
	/// first control settings that match.
	/// Params:
	/// 	controls = array of control settings to check
	private void move_impl(Controls[] controls)
	{
		foreach (c; controls)
		{
			if (areKeysPressed(c.keyCodes))
			{
				scene.camera.move(c.dx, c.dy, c.dz);
				scene.camera.rotate(c.dYaw, c.dRoll, c.dPitch);

				writefln("Camera movement: (x: %s y: %s z: %s) (yaw: %s roll: %s pitch: %s)",
						 c.dx, c.dy, c.dz, c.dYaw, c.dRoll, c.dPitch);

				needsRendering = true;
				break;
			}
		}
	}

	/// Checks if all of the specified SDL2 keys are pressed.
	private bool areKeysPressed(int[] keyCodes)
	{
		auto kbd = gui.sdl2.keyboard();

		foreach (key; keyCodes)
			if (!kbd.isPressed(key))
				return false;

		return true;
	}

	void printDebugInfo()
	{
		foreach (namedEntity; scene.namedEntities.tupleof)
			foreach (name, entity; namedEntity)
				writefln("'%s' -> %s", name, entity);
	}
}
