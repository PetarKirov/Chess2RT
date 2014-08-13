module gui.chessrt;

import rt.rtapp, gui.mainwindow, rt.scene, rt.color;

import ae.utils.graphics.image;

class ChessRT : RTApp
{
	private
	{
		Image!Color image;
		GUI gui;
	}

	this(size_t width, size_t height, string windowTitle)
	{
		gui = new GUI(width, height, windowTitle);
		image.size(width, height);
	}

	~this()
	{
		gui.close();
	}

	override void initScene()
	{

	}

	override void updateScene()
	{

	}

	override void renderScene()
	{

	}

	override void displayRenderedImage()
	{
		gui.draw(image);
	}

	override bool handleInput()
	{
		import core.thread, std.datetime;

		Thread.sleep(dur!"msecs"(5000));

		return false;
	}
}