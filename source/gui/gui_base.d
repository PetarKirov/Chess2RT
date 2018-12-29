module gui.guibase;

import std.experimental.logger : Logger, sharedLog;
import std.variant : Variant;
import gui.appsceleton, gui.sdl2gui;
import imageio.image : Image;

/// Base class based on SDL2 for GUI.
///
/// Params:
///     C = The type of the pixel color.
abstract class GuiBase(C) : AppSceleton
{
    protected
    {
        SDL2Gui gui;
        Image!C screen;
        Logger logger;
    }

    this(Logger customLogger)
    {
        this.logger = customLogger;
    }

    this(uint width, uint height, bool fullscreen, string windowTitle)
    {
        this(sharedLog);
        this.init(
            InitSettings(width, height, fullscreen, true, windowTitle)
            .Variant);
    }

    ~this()
    {
        logger.log("At ~GuiBase()");
    }

    static struct InitSettings
    {
        uint width, height;
        bool fullscreen, allowResize;
        string windowTitle;
    }

    override void init(Variant init_params)
    {
        if (init_params.peek!InitSettings is null)
            return;

        auto params = init_params.get!InitSettings;

        gui.init(params.width, params.height,
                params.fullscreen, params.allowResize,
                params.windowTitle, logger);

        screen.alloc(params.width, params.height);
    }

    override bool handleInput()
    {
        import gfm.sdl2 : SDLK_ESCAPE;

        return !gui.sdl2.keyboard().isPressed(SDLK_ESCAPE) &&
            !gui.sdl2.wasQuitRequested();
    }

    override void update()
    {
        gui.sdl2.processEvents();
    }

    override void render()
    {
    }

    final override void display()
    {
        gui.draw(screen);
    }
}
