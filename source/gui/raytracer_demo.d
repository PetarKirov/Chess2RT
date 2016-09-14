module gui.rtdemo;

import std.datetime.systime : Clock;
import std.datetime.stopwatch : benchmark;
import std.experimental.logger : Logger, sharedLog;
import std.format : format;
import std.stdio : writefln;
import std.typecons : Ternary;
import std.variant : Variant;

import derelict.sdl2.sdl;

import gui.guibase, gui.guidemo;
import rt.bitmap, rt.color, rt.renderer, rt.scene, rt.sceneloader,  rt.importedtypes : Vector;
import util.atomic : Atomic;

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
    import std.array : replace;

    auto time = Clock.currTime()
                    .toISOExtString()
                    .replace(":", "_");

    return format("output/img_%s.bmp", time);
}

class RTDemo : GuiBase!Color
{
    enum windowTitleFormat = r"Raytracing: `%s` ... ¯\_(ツ)_/¯";

    Scene scene;
    string sceneFilePath;
    shared Atomic!bool needsRendering;
    shared Atomic!bool isRendering;

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
        if (!this.isRendering && !needsRendering)
        {
            gui.resizeEnabled = scene.settings.allowResize;
            SDL_Event event;
            gui.sdl2.waitEvent(&event);
        }
    }

    override void render()
    {
        if (!needsRendering || isRendering)
            return;

        logger.log("Spawning render thread...");

        isRendering = true;

        updateToWindowSize();

        gui.resizeEnabled = false;

        /*
         * Ok to set to false here (and not when the rendering
         * thread finishes, because there's no danger of reentrancy
         * since we're synchronizing on the `isRendering` var too.
         */
        needsRendering = false;

        if (this.scene.settings.asyncRendering)
            renderSceneAsync(this.scene, this.screen,
                this.isRendering.ptr, this.needsRendering.ptr);
        else
            renderSceneSync(this.scene, this.screen,
                this.isRendering.ptr);
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
        if (!this.isRendering.cas(false, true))
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

        this.isRendering = false;
    }

    override bool handleInput()
    {
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
        import imageio.image : convertTo;
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
        writefln("  Raytrace [start = %s, dir = %s]", result.ray.orig, result.ray.dir);

        if (result.hitLight)
            writefln("    Hit light with color: %s", result.hitLightColor);

        else if(!result.closestNode)
            writefln("    Hit environment %s\n      Color: %s",
				typeid(scene.environment),
				scene.environment.getEnvironment(result.ray.dir));

        else
        {
            writefln("    Hit %s at distance %s", typeid(result.closestNode.geom), result.data.dist);
            writefln("      Color: %s", color);
            writefln("      Intersection point: %s", result.data.p);
            writefln("      Normal:             %s", result.data.normal);
            writefln("      UV coods:           [%s, %s]", result.data.u, result.data.v);
        }

        writefln("Raytracing completed!\n");
    }

    private void move()
    {
        import std.algorithm : find;
        import std.range.primitives;

        enum dMove = 32, dRotate = 4, mouseSpeed = 0.2;

        auto controls =
        [
            Controls ([SDLK_RIGHT, SDLK_LCTRL], 0, 0, 0, 0, dRotate),
            Controls ([SDLK_RIGHT, SDLK_LSHIFT], 0, 0, 0, -dRotate),
            Controls ([SDLK_RIGHT], dMove),
            Controls ([SDLK_d, SDLK_LCTRL], 0, 0, 0, 0, dRotate),
            Controls ([SDLK_d, SDLK_LSHIFT], 0, 0, 0, -dRotate),
            Controls ([SDLK_d], dMove),

            Controls ([SDLK_LEFT, SDLK_LCTRL], 0, 0, 0, 0, -dRotate),
            Controls ([SDLK_LEFT, SDLK_LSHIFT], 0, 0, 0, dRotate),
            Controls ([SDLK_LEFT], -dMove),
            Controls ([SDLK_a, SDLK_LCTRL], 0, 0, 0, 0, -dRotate),
            Controls ([SDLK_a, SDLK_LSHIFT], 0, 0, 0, dRotate),
            Controls ([SDLK_a], -dMove),

            Controls ([SDLK_DOWN, SDLK_LCTRL], 0, -dMove),
            Controls ([SDLK_DOWN, SDLK_LSHIFT], 0, 0, 0, 0, 0, -dRotate),
            Controls ([SDLK_DOWN], 0, 0, -dMove),
            Controls ([SDLK_s, SDLK_LCTRL], 0, -dMove),
            Controls ([SDLK_s, SDLK_LSHIFT], 0, 0, 0, 0, 0, -dRotate),
            Controls ([SDLK_s], 0, 0, -dMove),

            Controls ([SDLK_UP, SDLK_LCTRL], 0, dMove),
            Controls ([SDLK_UP, SDLK_LSHIFT], 0, 0, 0, 0, 0, dRotate),
            Controls ([SDLK_UP], 0, 0, dMove),
            Controls ([SDLK_w, SDLK_LCTRL], 0, dMove),
            Controls ([SDLK_w, SDLK_LSHIFT], 0, 0, 0, 0, 0, dRotate),
            Controls ([SDLK_w], 0, 0, dMove),
        ];

        int mouseDx, mouseDy;
        SDL_GetRelativeMouseState(&mouseDx, &mouseDy);

        auto pressedKeys = controls.find!(c => areKeysPressed(c.keyCodes));

        __gshared Controls c;
        if (!pressedKeys.empty || mouseDx || mouseDy)
        {
            // Communicate to the render threads that a new render request
            // has a arrived and they need to drop their current tasks.
            needsRendering = true;

            if (!pressedKeys.empty)
                c.m += pressedKeys.front.m;

            c.m.r += Vector(-mouseDx * mouseSpeed, 0, -mouseDy * mouseSpeed);

            // Ignore input events while rendering because we can't modify the scene.
            // Perhaps we can save the last input event and handle it
            // after we finish rendering.
            if (isRendering)
                return;

            this.scene.beginFrame(); // ensure the camera is initialized
            scene.camera.move(c.m.v.x, c.m.v.y, c.m.v.z);
            scene.camera.rotate(c.m.r.x, c.m.r.y, c.m.r.z);

            writefln("Camera movement: (x: %s y: %s z: %s) (yaw: %s roll: %s pitch: %s)",
                     c.m.v.x, c.m.v.y, c.m.v.z, c.m.r.x, c.m.r.y, c.m.r.z);

            c.m = Movement.init;

            needsRendering = true;
        }
    }

    /// Encapsulates a camera control keys binding.
    private static struct Controls
    {
        SDL_Keycode[] keyCodes;
        Movement m;

        this(SDL_Keycode[] keyCodes, double dx = 0.0, double dy = 0.0, double dz = 0.0,
            double dYaw = 0.0, double dRoll = 0.0, double dPitch = 0.0)
        {
            this.keyCodes = keyCodes;
            this.m.v.x = dx;
            this.m.v.y = dy;
            this.m.v.z = dz;
            this.m.r.x = dYaw;
            this.m.r.y = dRoll;
            this.m.r.z = dPitch;
        }
    }

    struct Movement
    {
        Vector v = Vector(0, 0, 0);
        Vector r = Vector(0, 0, 0);

        Movement opBinary(string op)(in ref Movement other)
        {
            Movement res;

            mixin ("res.v = this.v" ~ op ~ "other.v;");
            mixin ("res.r = this.r" ~ op ~ "other.r;");

            return res;
        }

        void opOpAssign(string op)(in ref Movement other)
        {
            mixin ("this = this" ~ op ~ "other;");
        }
    }

    /// Checks if all of the specified SDL2 keys are pressed.
    private bool areKeysPressed(SDL_Keycode[] keyCodes)
    {
        auto kbd = gui.sdl2.keyboard();

        foreach (key; keyCodes)
            if (!kbd.isPressed(key))
                return false;

        return true;
    }
}
