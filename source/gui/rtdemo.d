module gui.rtdemo;

import gui.guibase, rt.sceneloader, rt.scene, rt.renderer;
import rt.color;

class RTDemo : GuiBase!Color
{
	Scene scene;

	this(size_t width, size_t height, string windowTitle)
	{
		super(width, height, windowTitle);
	}

	override void init()
	{
		log.log("Loading scene!");

		scene = parseSceneFromFile(`D:\Pesho\develop\trinity\data\lecture4.json`);

		image.size(scene.settings.frameWidth, scene.settings.frameHeight);
	}

	override void render()
	{
		log.log("Rendering!!!");

		renderRT(this.image, this.scene);
	}
}