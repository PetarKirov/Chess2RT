module app;

import gui.rtdemo, gui.guidemo;
import core.stdc.stdlib : exit;
import std.getopt : getopt;
import std.stdio : writeln;
import std.typecons : scoped;

void main(string[] args)
{
	version(unittest) exit(0);

	string sceneFilePath = "";

	getopt(args, "file", &sceneFilePath);

	foreach (_; 0 .. 10)
		runAppInScope(sceneFilePath);

	debug printDiagnostics();

	writeln("At the end.");
}

void runAppInScope(string filePath)
{
	import std.variant : Variant;

	// auto app = scoped!(GuiDemo!uint)(800, 600, "Test GUI");
	auto app = scoped!RTDemo();

	bool normalQuit = app.run(Variant(filePath));

	if (normalQuit)
		writeln("User requested shutdown and the application is closing normally.");
	else
		writeln("Something bad happened during shutdown!");

	writeln("Close to the end...");
}

void printDiagnostics()
{
	import rt.shader;

	//writeln(Lambert.shadeFunc.callsCount);
	//writeln(Lambert.spawnRayFunc.callsCount);
	//writeln(Lambert.evalFunc.callsCount);
}
