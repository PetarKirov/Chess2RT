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

	if (sceneFilePath == "")
		sceneFilePath = getPathToDefaultScene;
	
	runAppInScope(sceneFilePath);
	
	debug printDiagnostics();
	
	writeln("At the end.");
}

/// If no file is specified at the command line
/// this function will return a path to
/// the default scene, read from the file
/// "data/default_scene.path"
@property string getPathToDefaultScene()
{
	import std.file, std.string : strip;

	// The path to the file containting the path to the default scene file
	enum link = "data/default_scene.path";
	assert(link.exists, "Missing link to default scene file!");

	auto finalPath = link.readText().strip();
	assert(finalPath.exists, "Missing default scene file!");

	return finalPath;
}

void runAppInScope(string filePath)
{
	//auto app = scoped!GuiDemo(800, 600, "Test GUI");
	auto app = scoped!RTDemo(filePath);

	bool normalQuit = app.run();

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
