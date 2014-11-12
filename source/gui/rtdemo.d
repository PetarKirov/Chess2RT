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
	shared uint tasksCount;

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

		debug if (tasksCount == 0)
		{
			auto t = task(&printMouse);
			taskPool.put(t);
			atomicOp!"+="(tasksCount, 1);
		}

		return super.handleInput;
	}

	private void printMouse()
	{
		auto mouse = gui.sdl2.mouse();
		
		if (!mouse.isButtonPressed(1)) //left mouse button
		{
			atomicOp!"-="(tasksCount, 1);
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
		
		atomicOp!"-="(tasksCount, 1);
	}

	void printDebugInfo()
	{
		foreach (namedEntity; scene.namedEntities.tupleof)
			foreach (name, entity; namedEntity)
				writefln("'%s' -> %s", name, to!string(entity));
	}
}
