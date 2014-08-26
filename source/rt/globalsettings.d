module rt.globalsettings;

import rt.color, rt.sceneloader;

class GlobalSettings : JsonDeserializer
{
	// General:
	uint frameWidth, frameHeight;
	bool fullscreen;             // [Not implemented] Fullscreen
	bool interactive;            // [Not implemented] Interactive mode

	// Multithreading:
	uint bucketSize;			// Image sub-rectange (square) width
	size_t threadCount;			// [Not implemented] Number of rendering threads; default (or 0) - autodetect
	
	// Rendering:
	bool prepassEnabled;		// Quick low-resolution preview rendering
	bool GIEnabled;				// Global Illumination
	bool AAEnabled;				// Anti-aliasing
	double AAThreshold;			// Color difference threshold, before AA is triggered

	// Shading:
	uint pathsPerPixel;			// Paths per pixel
	uint maxTraceDepth;			// Maximum recursion depth

	// Lighting:
	Color ambientLightColor;	// Color of the ambient light
	
	// Debug:
	bool debugEnabled;			// [Not implemented] If on, various raytracing-related procedures will dump debug info.

	/// Adjust the frame size to be a multiple of the bucketsize
	void adjustFrameSize()
	{
		if (frameWidth % bucketSize != 0) 
			frameWidth = (frameWidth / bucketSize + 1) * bucketSize;

		if (frameHeight % bucketSize != 0) 
			frameHeight = (frameHeight / bucketSize + 1) * bucketSize;
	}

	this()
	{
		frameWidth = 640;	//Will be adjusted to bucket size
		frameHeight = 480;
		fullscreen = false;
		interactive = false;

		bucketSize = 48;
		threadCount = 1;

		prepassEnabled = true;
		GIEnabled = false;
		AAEnabled = true;
		AAThreshold = 0.1;

		pathsPerPixel = 40;
		maxTraceDepth = 4;

		ambientLightColor = Color.black();

		debugEnabled = false;		
	}

	void loadFromJson(JSONValue json, SceneLoadContext context)
	{
		context.set(this.frameWidth, json, "frameWidth");
		context.set(this.frameHeight, json, "frameHeight");
		context.set(this.fullscreen, json, "fullscreen");
		context.set(this.interactive, json, "interactive");

		context.set(this.bucketSize, json, "bucketSize");
		context.set(this.threadCount, json, "threadCount");

		context.set(this.prepassEnabled, json, "prepassEnabled");
		context.set(this.GIEnabled, json, "GIEnabled");
		context.set(this.AAEnabled, json, "AAEnabled");
		context.set(this.AAThreshold, json, "AAThreshold");

		context.set(this.maxTraceDepth, json, "maxTraceDepth");
		context.set(this.pathsPerPixel, json, "pathsPerPixel");

		context.set(this.ambientLightColor, json, "ambientLightColor");

		context.set(this.debugEnabled, json, "debugEnabled");

		adjustFrameSize();
	}
}

