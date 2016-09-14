module rt.texture;

import rt.importedtypes, rt.ray, rt.intersectable, rt.color, rt.sceneloader;
import rt.bitmap;

abstract class Texture : Deserializable
{
    Color getTexColor(in ref IntersectionData info) const @safe @nogc pure;

    void modifyNormal(ref IntersectionData data) const @safe @nogc pure
    {
    }

    void toString(scope void delegate(const(char)[]) sink) const
    {
    }
}

/// A checker texture
class Checker : Texture
{
    Color color1, color2; /// the colors of the alternating squares
    double size; /// the size of a square side, in world units

    this() { this(Color(0, 0, 0)); }

    this(const Color color1 = Color(0, 0, 0),
         const Color color2 = Color(1, 1, 1),
         double size = 1.0)
    {
        this.color1 = color1;
        this.color2 = color2;
        this.size = size;
    }

    override Color getTexColor(in ref IntersectionData info) const @safe @nogc pure
    {
        /*
         * The checker texture works like that. Partition the whole 2D space
         * in squares of squareSize. Use division and floor()ing to get the
         * integral coordinates of the square, which our point happens to be. Then,
         * use the parity of the sum of those coordinates to decide which color to return.
        */

        // example - u = 150, v = -230, size = 100
        // -> 1, -3

        const x = cast(int)(floor(info.u / size));
        const y = cast(int)(floor(info.v / size));

        const white = (x + y) % 2;

        return white ? color2 : color1;
    }

    void deserialize(const SceneDscNode val, SceneLoadContext context)
    {
        context.set(this.color1, val, "color1");
        context.set(this.color2, val, "color2");
        context.set(this.size, val, "size");
    }

    override void toString(scope void delegate(const(char)[]) sink) const
    {
        import util.prettyprint : printMembers;
        //printMembers!(typeof(this), sink)(this);
    }
}

class Procedure2 : Texture
{
    Color[] colorU, colorV;
    double[] freqU, freqV;

    this() { }

    override Color getTexColor(in ref IntersectionData info) const @safe @nogc pure
    {
        auto result = Color(0, 0, 0);

        foreach (i; 0 .. 3)
            result += colorU[i] * sin(info.u * freqU[i]) +
                colorV[i] * sin(info.v * freqV[i]);

        return result;
    }

    void deserialize(const SceneDscNode val, SceneLoadContext context)
    {
        context.set(this.colorU, val, "colorU");
        context.set(this.colorV, val, "colorV");
        context.set(this.freqU, val, "freqU");
        context.set(this.freqV, val, "freqV");
    }

    override void toString(scope void delegate(const(char)[]) sink) const
    {
        import util.prettyprint : printMembers;
        //printMembers!(typeof(this), sink)(this);
    }
}

class BitmapTexture : Texture
{
    this()
    {
        this(1, 2.2f);
    }

    this (float scaling, float assumedGamma)
    {
        this.scaling = scaling;
        this.assumedGamma = assumedGamma;
    }

    override Color getTexColor(in ref IntersectionData info) const @safe @nogc pure
    {
        double u = info.u, v = info.v;
        u *= scaling;
        v *= scaling;
        // u, v range in [0..1):
        u = u - floor(u);
        v = v - floor(v);
        float tx = cast(float) u * bmp.width; // u is in [0..textureWidth)
        float ty = cast(float) v * bmp.height; // v is in [0..textureHeight)
        return bmp.getFilteredPixel(tx, ty); // fetch from the bitmap with bilinear filtering
    }

    void deserialize(const SceneDscNode val, SceneLoadContext context)
    {
        context.set(this.scaling, val, "scaling");
        context.set(this.assumedGamma, val, "assumedGamma");
        bmp = Bitmap();
        string fileName = context.resolveRelativePath(
                        context.get!string(val, "file"));
        bmp.loadImage(fileName);

        if (assumedGamma == 2.2f)
            bmp.decompressGamma_sRGB();

        else if (assumedGamma != 1 && assumedGamma > 0 && assumedGamma < 10)
            bmp.decompressGamma(assumedGamma);
    }

    override void toString(scope void delegate(const(char)[]) sink) const
    {
        import util.prettyprint;
        //printMembers!(typeof(this), sink)(this);
    }

private:
    Bitmap bmp;

    /// Scaling for the input (u, v) coords.
    /// Larger values SHRINK the texture on-screen.
    float scaling = 1;

    /// assumed gamma compression of the input image.
    /// - if  == 1, no gamma decompression is done.
    /// - if  == 2.2 (a special value) - sRGB decompression is done.
    /// - otherwise, gamma decompression with the given power is performed
    float assumedGamma = 2.2f;
}

class Fresnel : Texture
{
    double ior = 1.33;

    static float fresnel(float NdotI, float ior) @safe @nogc pure nothrow
    {
        alias sqr = (x) => x * x;

        // Schlick's approximation
        const float f = sqr((1.0f - ior) / (1.0f + ior));
        const float x = 1.0f - NdotI;
        return f + (1.0f - f) * (x * x * x * x * x);
    }

    @safe @nogc pure nothrow
    override Color getTexColor(in ref IntersectionData info) const
    {
        // fresnel() expects the IOR_WE_ARE_ENTERING : IOR_WE_ARE_EXITING, so
        // in the case we're exiting the geometry, be sure to take the reciprocal
        float eta = ior;
        float NdotI = dot(info.normal, info.ray.dir);

        if (NdotI > 0)
            eta = 1.0f / eta;
        else
            NdotI = -NdotI;

        const float fr = fresnel(NdotI, eta);
        return Color(fr, fr, fr);
    }

    void deserialize(const SceneDscNode val, SceneLoadContext context)
    {
        context.set(ior, val, "ior");
        ior = clamp(ior, 1e-6, 10);
    }
}
