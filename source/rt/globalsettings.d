module rt.globalSettings;

import std.json;
import rt.color, rt.sceneloader;

class GlobalSettings : JsonDeserializer
{
	int frameWidth, frameHeight; //!< render window size

	// Lighting:
	Color ambientLight;          //!< ambient color
	
	// AA-related:
	bool wantAA, wantPrepass;    //!< Antialiasing flag and prepass (a JSONValueuick low-resolution rendering) flag
	bool gi;                     //!< Is GI on?
	double aaThresh;             //!< The antialiasing color difference threshold (see renderScene)
	int numPaths;                //!< paths per pixel
	
	int maxTraceDepth;           //!< Maximum recursion depth
	
	bool dbg;                    //!< A debugging flag (if on, various raytracing-related procedures will dump debug info to stdout).
	
	int numThreads;              //!< # rendering threads (0 to autodetect)
	bool interactive;            //!< interactive mode
	bool fullscreen;             //!< fullscreen in interactive mode (default: true)

	//void fillProperties(ParsedBlock& pb);
	//ElementType getElementType() const { return ELEM_SETTINGS; }

	this()
	{
		frameWidth = 640;
		frameHeight = 480;
		wantAA = wantPrepass = true;
		aaThresh = 0.1;
		dbg = false;
		maxTraceDepth = 4;
		ambientLight.makeZero();
		gi = false;
		numPaths = 40;
		numThreads = 0;
		interactive = false;
		fullscreen = true;
	}

	void loadFromJson(JSONValue json, SceneLoadContext context)
	{
		context.set(this.dbg, json, "dbg");
		context.set(this.interactive, json, "interactive");
		context.set(this.fullscreen, json, "fullscreen");
		context.set(this.frameWidth, json, "frameWidth");
		context.set(this.frameHeight, json, "frameHeight");
		context.set(this.wantAA, json, "wantAA");
		context.set(this.wantPrepass, json, "wantPrepass");
		context.set(this.gi, json, "gi");
		context.set(this.aaThresh, json, "aaThresh");
		context.set(this.maxTraceDepth, json, "maxTraceDepth");
		context.set(this.ambientLight, json, "ambientLight");
		context.set(this.numPaths, json, "numPaths");
		context.set(this.numThreads, json, "numThreads");
	}
}

