module gui.guidemo;

import std.math : atan2, abs, PI, sqrt;
import std.algorithm.comparison : min;
import gui.sdl2gui, gui.guibase;
import imageio.image : Image;
import util.prop;
import std.stdio : writeln, writefln;

import std.algorithm : clamp;
import std.range : iota, chunks;
import std.parallelism : parallel;
import std.random : uniform;

class GuiDemo(T) : GuiBase!T
{
    private bool needsRendering = true;

    private float speed = 0.005;

    mixin ObservableProperty!(float, "size", q{ needsRendering = true }, q{ 0.5 });

    this(uint width, uint height, string windowTitle)
    {
        super(width, height, windowTitle);
    }

    override void render()
    {
        if (!needsRendering) return;

        getImage().cropCopyTo(screen);
        //screen.drawCircle(size);

        needsRendering = false;
    }

    override void update()
    {
        super.update;

        if (size <= 0.0 || size >= 1.0)
            speed *= -1;

        size = clamp(size + speed, 0f, 1f);
    }

    override bool handleInput()
    {
        import derelict.sdl2.types;

        auto kbd = gui.sdl2.keyboard();

        if (kbd.isPressed(SDLK_UP))
            size = min(1.0, size + 0.01);

        if (kbd.isPressed(SDLK_DOWN))
            size = fmax(0.0, size - 0.01);

        return super.handleInput;
    }
}

/// Draws a [green, blue] radial gradient on a red background
void drawCircle(Image!uint screen, float diameterToWidthRatio = 0.5)
{
    auto w = screen.width, h = screen.height;

    double radius = diameterToWidthRatio * min(w, h) / 2;

    double cx = w / 2;
    double cy = h / 2;

    import rt.color;

    enum dirs = 360 * 10;
    enum beam_width = 40;
    enum beam_length = 40f;

    float[] beams = new float[dirs];

    foreach (beam; beams.chunks(beam_width))
        beam[] = uniform(0f, beam_length);

    auto scale(T, U)(T from, T to, U value) { return from + (to - from) * value; }
    auto normalize(T)(T from, T to, T value){ return (value - from) / (to - from); }

    auto circle_func = (size_t x, size_t y)
    {
        auto dx = (cx - x), dy = (y - cy);
        auto dist = sqrt(dx*dx + dy*dy);

        enum ci = NamedColors.red;
        enum co = NamedColors.purple;
        enum ce = NamedColors.yellow;

        if (dist < radius)
            return ce.toRGB32Raw;
        else
        {
            auto tan = atan2(cast(double)dy, cast(double)dx);

            auto idx = normalize(-PI, PI, tan);
            auto edge = beams[cast(int)((dirs - 1) * idx)];
            auto delta = dist - radius;

            //writefln("xy: (%s, %s) tan: %s idx: %s edge: %s", dx, dy, tan, idx, edge);

            if (delta < edge)
                return scale(NamedColors.green, NamedColors.pink, delta / edge).toRGB32Raw;
            else
                return co.toRGB32Raw;
        }
    };

    foreach (y; h.iota.parallel)
        foreach (x; w.iota)
            screen[x, y] = circle_func(x, y);

    version (none)
    {

    auto pink = NamedColors.pink;
    auto purple = NamedColors.purple;

    auto start = purple;
    auto diff = pink - purple;

//  auto diff = ARGB2(
//      (cast(int)pink.r - purple.r),
//      (cast(int)pink.g - purple.g),
//      (cast(int)pink.b - purple.b));

//  auto diff = ARGB3(
//      pink.red - purple.red,
//      pink.green - purple.green,
//      pink.blue - purple.blue);
//
    foreach (y; 0 .. h)
    {
        foreach (x; 0 .. w)
        {
            auto ratio = cast(float)x / w;

            auto color =  start + ratio * diff;

            screen[x, y] = color.toRGB32Raw;
        }
    }
    }
}

Image!ARGB getImage(string imgPath = "data/texture/zaphod.bmp")
{
    import imageio.bmp;
    import std.file : read;

    return imgPath.read().loadBmpImage!ARGB;
}

void cropCopyTo(Img1, Img2)(Img1 source, Img2 dest)
{
    foreach (y; 0 .. dest.h)
        foreach (x; 0 .. dest.w)
            if (x < source.w && y < source.h)
                dest[x, y] = cast(typeof(dest[0, 0]))source[x, y];
            else
                dest[x, y] = 0;
}

void scaleCopyTo(Img1, Img2)(Img1 source, Img2 dest)
{
    foreach (y; 0 .. dest.h)
        foreach (x; 0 .. dest.w)
        {
            // TODO...
        }
}

struct ARGB2
{
    union
    {
        int[4] value;
        struct { int b, g, r, a; }
    }

    this (int r_, int g_, int b_) { r = r_; g = g_; b = b_;}
}

struct ARGB3
{
    import std.bitmanip : bitfields;

    mixin (bitfields!(
            ubyte, "b_", 8,
            ubyte, "g_", 8,
            ubyte, "r_", 8,
            ubyte, "a_", 4,
            bool, "isAlphaNegative", 1,
            bool, "isRedNegative", 1,
            bool, "isBlueNegative", 1,
            bool, "isGreenNegative", 1));

    this (int red_, int green_, int blue_, int alpha_ = 0)
    {
        this.r_ = abs(red_)   & 0xFF;
        this.g_ = abs(green_) & 0xFF;
        this.b_ = abs(blue_)  & 0xFF;
        this.a_ = abs(alpha_) & 0xF;

        this.isRedNegative = red_ < 0;
        this.isGreenNegative = green_ < 0;
        this.isBlueNegative = blue_ < 0;
        this.isAlphaNegative = alpha_ < 0;
    }

    @property
    {
        int red()
        {
            return isRedNegative? -cast(int)r_ : r_;
        }

        int green()
        {
            return isGreenNegative? -cast(int)g_ : g_;
        }

        int blue()
        {
            return isBlueNegative? -cast(int)b_ : b_;
        }

        int alpha()
        {
            return isAlphaNegative? -cast(int)a_ : a_;
        }
    }
}

struct ARGB
{
    union
    {
        uint value;
        struct { ubyte b, g, r, a; }
    }

pure:

    this (uint hexColor) { this.value = hexColor; }
    this (ubyte r_, ubyte g_, ubyte b_) { r = r_; g = g_; b = b_;}
    T opCast(T)() if (is(T == uint)) { return value; }
}

unittest
{
    auto alpha = ARGB(0xFF000000);
    auto red = ARGB(0x00FF0000);
    auto green = ARGB(0x0000FF00);
    auto blue = ARGB(0x000000FF);

    assert(alpha.a == 255);
    assert(red.r == 255);
    assert(green.g == 255);
    assert(blue.b == 255);
}
