module gui.rtdemo;

import std.experimental.logger;
import gui.guibase, rt.renderer, rt.scene, rt.sceneloader, rt.color;

class RTDemo : GuiBase!Color
{
	string sceneFilePath;
	Scene scene;
	bool rendered;

	this(Logger log, string sceneFilePath_)
	{
		super(log);
		this.sceneFilePath = sceneFilePath_;
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
	}

	override void render()
	{
		//No need for re-rendering - nothing changes in the main loop.
		if (rendered)
			return;

		log.log("Rendering!!!");

		scene.beginFrame();
		Renderer r = new Renderer(scene, screen);

		import std.datetime;
		auto time = benchmark!(() => r.renderRT())(1);
		log.logf("Time to render: %ss", time[0].msecs / 1000.0);

		rendered = true;
	}

	~this()
	{
		log.log("At ~RTDemo");	
	}
}