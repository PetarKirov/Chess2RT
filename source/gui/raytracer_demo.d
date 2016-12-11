module gui.rtdemo;

import core.atomic : atomicLoad, atomicStore, cas;
import std.stdio : writefln;
import std.format : format;
import std.datetime : benchmark, Clock;
import std.experimental.logger : Logger, sharedLog;
import gui.guibase, rt.renderer, rt.scene, rt.sceneloader, rt.color;

// Ugly hack necessary to support unofficial / unreleased / dev compiler versions
static if(__traits(compiles, { import std.typecons : Ternary; }))
    import std.typecons : Ternary;

else static if(__traits(compiles,
	{ import std.experimental.allocator.common : Ternary; }))
    import std.experimental.allocator.common : Ternary;

else
{
    import std.conv : to;
    static assert (0, "Unsupported compiler: " ~ __VENDOR__ ~
        " v" ~ __VERSION__.to!string ~
	". Reason: Ternary not found");
}

/// Returns a path to the default scene
/// read from the file "data/default_scene.path"
string getPathToDefaultScene()
{
    import std.file : exists, readText;
    import std.string : strip;

    // The path to the file containting the path to the default scene file
    enum link = "data/default_scene.path";
    assert(link.exists, "Missing link to default scene file!");

    auto finalPath = link.readText().strip();
    assert(finalPath.exists, "Missing default scene file!");

    return finalPath;
}

string getNewImageFileName()
{
    import std.format : format;
    import std.array : replace;

    auto time = Clock.currTime()
                    .toISOExtString()
                    .replace(":", "_");

    return format("output/img_%s.bmp", time);
}

import gui.guidemo, imageio.image;;

class RTDemo : GuiBase!Color
{
    enum windowTitleFormat = r"Raytracing: `%s` ... ¯\_(ツ)_/¯";

    Scene scene;
    string sceneFilePath;
    bool needsRendering;
    shared bool isRendering;

    this(Logger log = sharedLog)
    {
        super(log);

        logger.log("At RTDemo.ctor");
    }

    ~this()
    {
        logger.log("At RTDemo.dtor");
    }

    override void init(Variant init_settings)
    {
        this.sceneFilePath = init_settings.get!string == "" ?
            getPathToDefaultScene() :
            init_settings.get!string;

        resetScene(true);
    }

    override void update()
    {
        gui.sdl2.processEvents();

        /*
         * Block the UI event loop if there's nothing going on,
         * in order to avoid needless polling. Otherwise, keep
         * updating the screen.
         */
        if (!atomicLoad(this.isRendering) && !needsRendering)
        {
            gui.resizeEnabled = scene.settings.allowResize;
            import derelict.sdl2.sdl : SDL_Event;
            SDL_Event event;
            gui.sdl2.waitEvent(&event);
        }
    }

    override void render()
    {
        if (!needsRendering || atomicLoad(isRendering))
            return;

        logger.log("Spawning render thread...");

        isRendering.atomicStore(true);

        updateToWindowSize();

        gui.resizeEnabled = false;

        /*
         * Ok to set to false here (and not when the rendering
         * thread finishes, because there's no danger of reentrancy
         * since we're synchronizing on the `isRendering` var too.
         */
        needsRendering = false;

        renderSceneAsync(this.scene, this.screen, &this.isRendering);
    }

    void updateToWindowSize()
    {
        if (!scene.settings.allowResize || scene.settings.fullscreen)
            return;

        auto s = gui.getSize();
        if (s.x == scene.settings.frameWidth && s.y == scene.settings.frameHeight)
            return;

        scene.settings.frameWidth = s.x;
        scene.settings.frameHeight = s.y;

        if (scene.settings.dynamicAspectRatio)
            scene.camera.setFrameSize(s.x, s.y);

        screen.alloc(s.x, s.y);
        this.gui.setSize(s.x, s.y, Ternary.unknown);
    }

    void resetScene(bool newWindow = false)
    {
        if (!cas(&(this.isRendering), false, true))
            return;

        logger.logf("Resetting state. New app instance: %s.", newWindow);

        logger.logf("Loading scene: %s...", sceneFilePath);

        this.scene = parseSceneFromFile(sceneFilePath);

        logger.logf("Scene parsed successfully:\n%s", this.scene);

        this.needsRendering = true;

        if (newWindow)
        {
            gui.init(scene.settings.frameWidth,
                 scene.settings.frameHeight,
                 scene.settings.fullscreen,
                 scene.settings.allowResize,
                 windowTitleFormat.format(sceneFilePath),
                 logger);
        }
        else
        {
            this.gui.setTitle(windowTitleFormat.format(sceneFilePath));
            this.gui.setSize(
                    scene.settings.frameWidth,
                    scene.settings.frameHeight,
                    Ternary(scene.settings.fullscreen));
        }

        this.gui.setFocus();

        //Set the screen size according to the settings in the scene file
        screen.alloc(scene.settings.frameWidth,
                    scene.settings.frameHeight);

        logger.log("State successfully reset.");

        this.isRendering.atomicStore(false);
    }

    override bool handleInput()
    {
        import derelict.sdl2.types;

        // Sync w.r.t. rendering (changes state)
        if (scene.settings.interactive)
            move();

        auto mouse = gui.sdl2.mouse();
        auto kbd = gui.sdl2.keyboard();

        if (kbd.testAndRelease(SDLK_RETURN))
        {
            if (kbd.testAndRelease(SDLK_LALT) || kbd.testAndRelease(SDLK_RALT))
            {
                scene.settings.fullscreen = !scene.settings.fullscreen;
                this.gui.setSize(
                    scene.settings.frameWidth,
                    scene.settings.frameHeight,
                    Ternary(scene.settings.fullscreen));
            }

            this.needsRendering = true;
        }

        // Async w.r.t. rendering
        if (mouse.isButtonPressed(SDL_BUTTON_LMASK))
            printMouse(mouse.x, mouse.y);

        // Async w.r.t. rendering too
        if (kbd.testAndRelease(SDLK_F12))
            takeScreenshot();

        // Async w.r.t. rendering too^2
        if (kbd.testAndRelease(SDLK_r))
            resetScene();

        return super.handleInput;
    }

    void takeScreenshot()
    {
        import rt.bitmap;
        import std.file : mkdir, exists;

        if (!exists("output"))
            mkdir("output");

        //auto bitmap = const Bitmap(this.screen);
        auto bitmap = const Bitmap(this.screen.convertTo!Color);
        bitmap.saveImage(getNewImageFileName());
    }

    private void printMouse(int x, int y)
    {
        auto res = renderPixel(this.scene, this.screen, x, y);
        auto color = res[0];
        auto result = res[1];


        writefln("Mouse click at: (%s %s)", x, y);
        writefln("  Raytrace[start = %s, dir = %s]", result.ray.orig, result.ray.dir);

        if (result.hitLight)
            writefln("    Hit light with color: ", result.hitLightColor);

        else if(!result.closestNode)
            writefln("    Hit environment: ", scene.environment.getEnvironment(result.ray.dir));

        else
        {
            writefln("    Hit %s at distance %s", typeid(result.closestNode.geom), result.data.dist);
            writefln("      Color: %s", color);
            writefln("      Intersection point: %s", result.data.p);
            writefln("      Normal:             %s", result.data.normal);
            writefln("      UV coods:           %s, %s", result.data.u, result.data.v);
        }

        writefln("Raytracing completed!\n");
    }

    private void move()
    {
        // Ignore input events while rendering because we can't modify the scene.
        // Perhaps we can save the last input event and handle it
        // after we finish rendering.
        if (atomicLoad(isRendering))
            return;

        import derelict.sdl2.types;

        enum dMove = 32, dRotate = 4;

        auto controls =
        [
            Controls ([SDLK_RIGHT, SDLK_LCTRL], 0, 0, 0, 0, dRotate),
            Controls ([SDLK_RIGHT, SDLK_LSHIFT], 0, 0, 0, -dRotate),
            Controls ([SDLK_RIGHT], dMove),

            Controls ([SDLK_LEFT, SDLK_LCTRL], 0, 0, 0, 0, -dRotate),
            Controls ([SDLK_LEFT, SDLK_LSHIFT], 0, 0, 0, dRotate),
            Controls ([SDLK_LEFT], -dMove),

            Controls ([SDLK_DOWN, SDLK_LCTRL], 0, -dMove),
            Controls ([SDLK_DOWN, SDLK_LSHIFT], 0, 0, 0, 0, 0, -dRotate),
            Controls ([SDLK_DOWN], 0, 0, -dMove),

            Controls ([SDLK_UP, SDLK_LCTRL], 0, dMove),
            Controls ([SDLK_UP, SDLK_LSHIFT], 0, 0, 0, 0, 0, dRotate),
            Controls ([SDLK_UP], 0, 0, dMove),
        ];

        move_impl(controls);
    }

    /// Encapsulates a camera control keys binding.
    private static struct Controls
    {
        int[] keyCodes;
        double dx = 0.0, dy = 0.0, dz = 0.0;
        double dYaw = 0.0, dRoll = 0.0, dPitch = 0.0;

        /// Params:
        ///     keyCodes =  array of SDL2 key codes to test
        ///     dx =        left/right movement
        ///     dy =        up/down movement
        ///     dz =        forward/backword movement
        ///     dYaw =      left/right rotation [0..360]
        ///     dRoll =     roll rotation [-180..180]
        ///     dPitch =    up/down rotation [-90..90]
        this(int[] keyCodes, double dx = 0.0, double dy = 0.0, double dz = 0.0,
            double dYaw = 0.0, double dRoll = 0.0, double dPitch = 0.0)
        {
            this.keyCodes = keyCodes;
            this.dx = dx;
            this.dy = dy;
            this.dz = dz;
            this.dYaw = dYaw;
            this.dRoll = dRoll;
            this.dPitch = dPitch;
        }
    }

    /// Moves and/or rotates the camera according to the
    /// first control settings that match.
    /// Params:
    ///     controls = array of control settings to check
    private void move_impl(Controls[] controls)
    {
        foreach (c; controls)
        {
            if (areKeysPressed(c.keyCodes))
            {
                this.scene.beginFrame(); // ensure the camera is initialized
                scene.camera.move(c.dx, c.dy, c.dz);
                scene.camera.rotate(c.dYaw, c.dRoll, c.dPitch);

                writefln("Camera movement: (x: %s y: %s z: %s) (yaw: %s roll: %s pitch: %s)",
                         c.dx, c.dy, c.dz, c.dYaw, c.dRoll, c.dPitch);

                needsRendering = true;
                break;
            }
        }
    }

    /// Checks if all of the specified SDL2 keys are pressed.
    private bool areKeysPressed(int[] keyCodes)
    {
        auto kbd = gui.sdl2.keyboard();

        foreach (key; keyCodes)
            if (!kbd.isPressed(key))
                return false;

        return true;
    }
}
