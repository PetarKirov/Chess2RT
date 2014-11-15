module rt.globalsettings;

import rt.color, rt.sceneloader;

class GlobalSettings : Deserializable
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

		ambientLightColor = NamedColors.black;

		debugEnabled = false;		
	}

	void deserialize(const Value val, SceneLoadContext context)
	{
		context.set(this.frameWidth, val, "frameWidth");
		context.set(this.frameHeight, val, "frameHeight");
		context.set(this.fullscreen, val, "fullscreen");
		context.set(this.interactive, val, "interactive");

		context.set(this.bucketSize, val, "bucketSize");
		context.set(this.threadCount, val, "threadCount");

		context.set(this.prepassEnabled, val, "prepassEnabled");
		context.set(this.GIEnabled, val, "GIEnabled");
		context.set(this.AAEnabled, val, "AAEnabled");
		context.set(this.AAThreshold, val, "AAThreshold");

		context.set(this.maxTraceDepth, val, "maxTraceDepth");
		context.set(this.pathsPerPixel, val, "pathsPerPixel");

		context.set(this.ambientLightColor, val, "ambientLightColor");

		context.set(this.debugEnabled, val, "debugEnabled");
	}
}

