module gui.rtdemo;

import core.atomic : atomicOp;
import std.conv : to;
import std.stdio : writeln, writefln;
import std.datetime : benchmark;
import std.experimental.logger;
import gui.guibase, rt.renderer, rt.scene, rt.sceneloader, rt.color;

class RTDemo : GuiBase!Color
{
	string sceneFilePath;
	Scene scene;
	Renderer renderer;
	shared bool rendered;
	shared byte[] tasksCount = new shared byte[2];

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
	}

	override void render()
	{
		//No need for re-rendering - nothing changes in the main loop.
		if (rendered)
			return;

		log.log("Rendering!!!");

		scene.beginFrame();

		auto time = benchmark!(() => renderer.renderRT())(1);
		log.logf("Time to render: %ss", time[0].msecs / 1000.0);

		rendered = true;
	}

	override bool handleInput()
	{
		import core.atomic : atomicOp;
		import std.parallelism : task, taskPool;

		if (scene.settings.interactive)
			move();

		debug if (tasksCount[0] == 0)
		{
			atomicOp!"+="(tasksCount[0], 1);
			auto t = task(&printMouse);
			taskPool.put(t);
		}

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
		
		auto ray = scene.camera.getScreenRay(mouse.x, mouse.y);
		ray.isDebug = true;
		
		renderer.raytrace(ray);
		
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

		move_impl(SDLK_RIGHT, 32, 0);  //Right is Pressed
		move_impl(SDLK_LEFT, -32, 0); //Left is Pressed
		move_impl(SDLK_DOWN, 0, -32);  //Down is Pressed
		move_impl(SDLK_UP, 0, 32); //Up is Pressed
	}

	private void move_impl(int kbd_key, int dx, int dz)
	{
		auto kbd = gui.sdl2.keyboard();

		if (!kbd.isPressed(kbd_key))
			return;

		import derelict.sdl2.types;
		bool shouldRotate = kbd.isPressed(SDLK_LSHIFT);

		if (shouldRotate)
			scene.camera.rotate(dx / -8, dz / 8);
		else
			scene.camera.move(dx, dz);

		rendered = false;
		scene.camera.beginFrame();
	}

	void printDebugInfo()
	{
		foreach (namedEntity; scene.namedEntities.tupleof)
			foreach (name, entity; namedEntity)
				writefln("'%s' -> %s", name, to!string(entity));
	}
}
