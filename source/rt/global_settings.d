module rt.globalsettings;

import rt.color, rt.sceneloader;

class GlobalSettings : Deserializable
{
    // General:
    uint frameWidth = 640;              // Frame size; will be adjusted
    uint frameHeight = 480;             // to bucket size.
    bool fullscreen = false;            // Fullscreen mode?
    bool allowResize = false;           // Allow window resize when not in fullscreen mode
    bool dynamicAspectRatio;            // If the camera.aspectRatio should be update after window resize?
    bool interactive = false;           // Interactive mode?
	bool asyncRendering = true;         // Display intermedieate result of rendering?

    // Multithreading:
    uint bucketSize = 48;               // Image sub-rectange (square) width.
    uint threadCount = 0;               // Number of rendering threads; default (or 0) - autodetect.

    // Rendering:
    bool prepassEnabled = true;         // Quick low-resolution preview rendering.
    bool prepassOnly = false;           // Render only prepass.
    bool GIEnabled = false;             // Global Illumination.
    bool AAEnabled = true;              // Anti-aliasing.
    double AAThreshold = 0.1;           // Color difference threshold, before AA is triggered.

    // Shading:
    uint pathsPerPixel = 40;            // Paths per pixel.
    uint maxTraceDepth = 4;             // Maximum recursion depth.

    // Lighting:
    Color ambientLightColor =           // Color of the ambient light.
        NamedColors.black;

    // Debug:
    bool debugEnabled = true;           // [Not implemented] If on, various raytracing-related procedures will dump debug info.

    /// Adjust the frame size to be a multiple of the bucketsize
    void adjustFrameSize()
    {
        if (frameWidth % bucketSize != 0)
            frameWidth = (frameWidth / bucketSize + 1) * bucketSize;

        if (frameHeight % bucketSize != 0)
            frameHeight = (frameHeight / bucketSize + 1) * bucketSize;
    }

    void deserialize(const SceneDscNode val, SceneLoadContext context)
    {
        context.set(this.frameWidth, val, "frameWidth");
        context.set(this.frameHeight, val, "frameHeight");
        context.set(this.fullscreen, val, "fullscreen");
        context.set(this.allowResize, val, "allowResize");
        context.set(this.dynamicAspectRatio, val, "dynamicAspectRatio");
        context.set(this.interactive, val, "interactive");
		context.set(this.asyncRendering, val, "asyncRendering");

        context.set(this.bucketSize, val, "bucketSize");
        context.set(this.threadCount, val, "threadCount");

        context.set(this.prepassEnabled, val, "prepassEnabled");
        context.set(this.prepassOnly, val, "prepassOnly");
        context.set(this.GIEnabled, val, "GIEnabled");
        context.set(this.AAEnabled, val, "AAEnabled");
        context.set(this.AAThreshold, val, "AAThreshold");

        context.set(this.maxTraceDepth, val, "maxTraceDepth");
        context.set(this.pathsPerPixel, val, "pathsPerPixel");

        context.set(this.ambientLightColor, val, "ambientLight");

        context.set(this.debugEnabled, val, "debugEnabled");
    }

    void toString(scope void delegate(const(char)[]) sink) const @trusted
    {
        import util.prettyprint;
        printMembers!(typeof(this), sink)(this);
    }
}

