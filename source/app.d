module app;

import std.stdio, std.typecons;
import gui.guidemo, gui.rtdemo;

void runInScope()
{
	auto app = scoped!RTDemo(640, 480, "Ray tracer demo!");
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

	writeln("At the end.");
}