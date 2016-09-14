module rt.color;

import std.math;

pure nothrow @safe @nogc
{
    /// Combines the results from the "left" and "right" camera for a single pixel.
    /// the implementation here creates an anaglyph image: it desaturates the input
    /// colors, masks them (left=red, right=cyan) and then merges them.
    Color combineStereo(Color left, Color right)
    {
        left.adjustSaturation(0.25f);
        right.adjustSaturation(0.25f);
        return left * Color(1, 0, 0) + right * Color(0, 1, 1);
    }

    /// checks if two colors are "too different":
    bool tooDifferent(in Color lhs, in Color rhs, in float threshold = 0.1f)
    {
        return (fabs(lhs.r - rhs.r) > threshold ||
                fabs(lhs.g - rhs.g) > threshold ||
                fabs(lhs.b - rhs.b) > threshold);
    }
}

/// Represents a color, using floating point components in [0..1]
struct Color
{
    // The default value of float.nan makes the calculations
    // very slow in the toRGB32() functions.
    //float[3] components = [ 0f, 0f, 0f ];

    float r = 0, g = 0, b = 0;

    invariant
    {
        import std.math : isFinite;

        if (!__ctfe)
        {
            assert (r.isFinite);
            assert (g.isFinite);
            assert (b.isFinite);
        }
    }

    void toString(scope void delegate(const(char)[]) sink) const
    {
        import std.conv;
        sink("(");
        sink(to!string(r));
        sink(", ");
        sink(to!string(g));
        sink(", ");
        sink(to!string(b));
        sink(")");
    }

pure nothrow @safe @nogc:

    /// Construct a Color from floating point values.
    this(float r_, float g_, float b_)
    {
        this.r = r_;
        this.g = g_;
        this.b = b_;
    }

    /// Construct a color from R8G8B8 value like "0xffce08".
    this(uint rgbColor)
    {
        enum divider = 1.0f / 255.0f;
        r = ((rgbColor >> 16) & 0xff) * divider;
        g = ((rgbColor >> 8) & 0xff) * divider;
        b = ((rgbColor >> 0) & 0xff) * divider;
    }

//    this(ubyte r_, ubyte g_, ubyte b_) //!< Construct a color from R8G8B8 value like "0xffce08"
//    {
//        enum divider = 1.0f / 255.0f;
//        r = r_ * divider;
//        g = g_ * divider;
//        b = b_ * divider;
//    }

    /// 0 = desaturate; 1 = don't change
    void adjustSaturation(float amount)
    {
        float mid = intensity();
        r = r * amount + mid * (1 - amount);
        g = g * amount + mid * (1 - amount);
        b = b * amount + mid * (1 - amount);
    }

    inout(float) opIndex(int index) inout @trusted
    {
        return *(cast(float*)(&this.r) + index);
    }

    /// Accumulates some color to the current
    void opOpAssign(string op)(const Color rhs)
        if (op == "+")
    {
        r += rhs.r;
        g += rhs.g;
        b += rhs.b;
    }

    void opOpAssign(string op)(float multiplier)
        if (op == "*")
    {
        assert(multiplier >= 0.0 && multiplier <= 1.0);

        r *= multiplier;
        g *= multiplier;
        b *= multiplier;
    }

    void opOpAssign(string op)(float divider)
        if (op == "/")
    {
        assert(divider >= 0.0 && divider >= 1.0);

        float rdivider = 1.0f / divider;
        r *= rdivider;
        g *= rdivider;
        b *= rdivider;
    }

const:

    Color opBinary(string op)(const Color rhs)
        if (op == "+" || op == "-" || op == "*")
    {
        return mixin("Color(r" ~ op ~ "rhs.r, g" ~ op ~ "rhs.g, b" ~ op ~ "rhs.b)");
    }

    Color opBinary(string op)(float f)
        if (op == "*" || op == "/")
    {
        return mixin("Color(r " ~ op ~ " f, g " ~ op ~ " f, b " ~ op ~ " f)");
    }

    Color opBinaryRight(string op)(float f)
        if (op == "*")
    {
        return mixin("Color(r " ~ op ~ " f, g " ~ op ~ " f, b " ~ op ~ " f)");
    }

    /// get the intensity of the color (direct)
    float intensity()
    {
        return (r + g + b) / 3;
    }

    /// get the perceptual intensity of the color
    float intensityPerceptual()
    {
        return cast(float)(r * 0.299 + g * 0.587 + b * 0.114);
    }

    /// convert to RGB32, with channel shift specifications. The default values are for
    /// the blue channel occupying the least-significant byte
    uint toRGB32(uint redShift = 16, uint greenShift = 8, uint blueShift = 0)
    {
        uint ir = convertTo8bit_sRGB_Cached(r);
        uint ig = convertTo8bit_sRGB_Cached(g);
        uint ib = convertTo8bit_sRGB_Cached(b);
        return (ib << blueShift) |
               (ig << greenShift) |
               (ir << redShift);
    }

    uint toRGB32Raw(uint redShift = 16, uint greenShift = 8, uint blueShift = 0)
    {
        auto ir = r.roundToByte;
        auto ig = g.roundToByte;
        auto ib = b.roundToByte;

        return (ib << blueShift) |
               (ig << greenShift) |
               (ir << redShift);
    }

    T opCast(T)() if (is(T == uint))
    {
            return this.toRGB32();
    }

    static Color black() { return Color(0f, 0f, 0f); }
    static Color white() { return Color(1f, 1f, 1f); }
}

private pure nothrow @safe @nogc
{
    ubyte convertTo8bit(float x)
    {
        if (x <= 0f) return 0;
        if (x >= 1f) return 255;
        return roundToByte(x);
    }

    //TODO: Check sRGB transform formula
    ubyte convertTo8bit_sRGB(float x)
    {
        if (x <= 0) return 0;
        if (x >= 1) return 255;

        // sRGB transform:
        if (x <= 0.0031308f)
            x = x * 12.02f;
        else
            x = 1.055 * x^^(1 / 2.4) - 0.055;
        //x = (1.0f + a) * powf(x, 1.0f / 2.4f) - a; //const float a = 0.055f;

        return roundToByte(x);
    }

    ubyte convertTo8bit_sRGB_Cached(float x)
    {
        if (x <= 0) return 0;
        if (x >= 1) return 255;
        return SRGB_CompressCache[cast(int)(x * 4096.0f)];
    }

    ubyte roundToByte(float x)
    {
        return cast(ubyte)floor(x * 255.0f);
    }

    shared immutable ubyte[4097] SRGB_CompressCache;
    shared immutable float[4097] SRGB_DeCompressCache;

    shared static this()
    {
        foreach (i; 0 .. 4097)
            SRGB_CompressCache[i] = convertTo8bit_sRGB(i / 4096f);
    }
}

// TODO: Add more colors
/// A set of predefined colors
struct NamedColors
{
    enum Color black = Color(0f, 0f, 0f);
    enum Color white = Color(1f, 1f, 1f);
    enum Color red = Color(1f, 0f, 0f);
    enum Color green = Color(0f, 1f, 0f);
    enum Color blue = Color(0f, 0f, 1f);

    enum Color pink = Color(255, 87, 165);
    enum Color purple = Color(188, 94, 235);
    enum Color yellow = Color(255, 255, 0);
}
