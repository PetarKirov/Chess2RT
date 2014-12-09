module gui.rtdemo;

import core.atomic : atomicOp;
import std.conv : to;
import std.stdio : writeln, writefln;
import std.datetime : benchmark;
import std.experimental.logger;
import gui.guibase, rt.renderer, rt.scene, rt.sceneloader, rt.color;

import std.concurrency;


alias Args = shared Renderer;
alias Action = void function(Args r) @system;

void workerThread(Tid spawner)
{
	Action work;
	Args args;

	writeln("In other thread.");

	receive((Action a, Args s) { work = a; args = s; });

	writeln("Message recieved.");

	work(args);

	send(spawner, true);
}

class RTDemo : GuiBase!Color
{
	string sceneFilePath;
	Scene scene;
	Renderer renderer;
	shared bool rendered;
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
					  "RT Demo!");

		//Set the screen size according to the settings in the scene file
		screen.size(scene.settings.frameWidth,
					scene.settings.frameHeight);

		this.renderer = new Renderer(scene, screen);

		debug printDebugInfo();

		renderThread = spawn(&workerThread, thisTid);
	}

	override void render()
	{
		//No need for re-rendering - nothing changes in the main loop.
		if (rendered)
			return;

		log.log("Rendering!!!");

		scene.beginFrame();

		send(renderThread,
			 cast(Action)(shared Renderer r) @system
			 {
					(cast(Renderer)r).renderRT();
			 },
			 cast(Args)renderer);

		rendered = true;
	}

	override bool handleInput()
	{
		import core.atomic : atomicOp;
		import std.parallelism : task, taskPool;

		if (scene.settings.interactive)
		{
			move();
		}

		//printMouse();

		//debug if (tasksCount[0] == 0)
		//{
			//atomicOp!"+="(tasksCount[0], 1);
			//auto t = task(&printMouse);
			//taskPool.put(t);
		//}

		return super.handleInput;
	}

	private void printMouse()
	{
		auto mouse = gui.sdl2.mouse();
		
		if (!mouse.isButtonPressed(1)) //left mouse button
		{
			atomicOp!"-="(tasksCount[0], 1);
			return;
		}

		int x = mouse.x;
		int y = mouse.y;

		renderer.renderPixelNoAA(x, y);
		
		auto result = renderer.lastTracingResult;
		
		writefln("Mouse click at: (%s %s)", mouse.x, mouse.y);
		writefln("  Raytrace[start = %s, dir = %s]", result.ray.orig, result.ray.dir);
		
		if (result.hitLight)
			writeln("Hit light with color: ", to!string(result.hitLightColor));
		
		else if(!result.closestNode)
			writeln("Hit environment: ", to!string(scene.environment.getEnvironment(result.ray.dir)));
		
		else
		{
			writefln("    Hit %s at distance %s", typeid(result.closestNode.geom), result.data.dist);
			writefln("      Intersection point: %s", result.data.p);
			writefln("      Normal:             %s", result.data.normal);
			writefln("      UV coods:           %s, %s", result.data.u, result.data.v);
		}
		
		writeln("Raytracing completed!\n");
		
		atomicOp!"-="(tasksCount[0], 1);
	}

	private void move()
	{
		import derelict.sdl2.types;

		auto dMove = 32, dRotate = 4;

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

				rendered = false;
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
				writefln("'%s' -> %s", name, to!string(entity));
	}
}
