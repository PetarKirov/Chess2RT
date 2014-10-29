module app;

import std.stdio, std.typecons;
import gui.guidemo, gui.rtdemo, gui.sdl2gui;
import std.experimental.logger;

void runInScope()
{
	//auto app = scoped!GuiDemo(800, 600, "Test GUI");
	auto app = scoped!RTDemo(stdlog);
	bool normalQuit = app.run();

	if (normalQuit)
		writeln("User requested shutdown and the application is closing normally.");
	else
		writeln("Something bad happened during shutdown!");

	writeln("Close to the end...");
}

void main()
{
	runInScope();

	diag();

	writeln("At the end.");
}

void diag()
{
	import rt.shader;

	writeln(Lambert.shadeFunc.callsCount);
	writeln(Lambert.spawnRayFunc.callsCount);
	writeln(Lambert.evalFunc.callsCount);
}