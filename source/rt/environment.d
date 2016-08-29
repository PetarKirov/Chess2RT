module rt.environment;

import rt.importedtypes, rt.color, rt.sceneloader;

class Environment : Deserializable
{
    Color getEnvironment(const Vector dir) const @safe @nogc pure
    {
        return Color(0, 0, 0);
    }

    void deserialize(const SceneDscNode val, SceneLoadContext context)
    {
    }
}

class CubemapEnvironment : Environment
{
    import rt.bitmap : Bitmap;

    Bitmap[6] sides;

    this()
    {
    }

    enum CubeOrder
    {
        NEGX,
        NEGY,
        NEGZ,
        POSX,
        POSY,
        POSZ
    }

    override Color getEnvironment(const Vector indir) const @safe @nogc pure
    {
        Vector vec = indir;
        // Get a color from a cube-map
        // First, we get at which dimension, the absolute value of the direction is largest
        // (it is 0, 1 or 2, which is, respectively, X, Y or Z)
        int maxDim = vec.maxDimension();

        // Normalize the vector, so that now its largest dimension is either +1, or -1
        Vector t = vec / fabs(vec[maxDim]);

        // Create a state of (maximalDimension * 2) + (1 if it is negative)
        // so that:
        // if state is 0, the max dimension is 0 (X) and it is positive -> we hit the +X side
        // if state is 1, the max dimension is 0 (X) and it is negative -> we hit the -X side
        // if state is 2, the max dimension is 1 (Y) and it is positive -> we hit the +Y side
        // state is 3 -> -Y
        // state is 4 -> +Z
        // state is 5 -> -Z
        int state = ((t[maxDim] < 0) ? 0 : 3) + maxDim;

        auto getSide = (in ref Bitmap bmp, double x, double y) =>
            bmp.getFilteredPixel(
                float((x + 1) * 0.5 * (bmp.width - 1)),
                float((y + 1) * 0.5 * (bmp.height - 1))
            );


        switch (state) with (CubeOrder)
        {
            // for each case, we have to use the other two dimensions as coordinates within the bitmap for
            // that side. The ordering of plusses and minuses is specific for the arrangement of
            // bitmaps we use (the orientations are specific for vertical-cross type format, where each
            // cube side is taken verbatim from a 3:4 image of V-cross environment texture.

            // In every case, the other two coordinates are real numbers in the square (-1, -1)..(+1, +1)
            // We use the getSide() helper function, to convert these coordinates to texture coordinates and fetch
            // the color value from the bitmap.
            case 0: return getSide(this.sides[NEGX], t.z, -t.y);
            case 1: return getSide(this.sides[NEGY], t.x, -t.z);
            case 2: return getSide(this.sides[NEGZ], t.x, t.y);
            case 3: return getSide(this.sides[POSX], -t.z, -t.y);
            case 4: return getSide(this.sides[POSY], t.x, t.z);
            case 5: return getSide(this.sides[POSZ], t.x, -t.y);
            default: return Color(0.0f, 0.0f, 0.0f);
        }
    }

    private void loadFromFolder(string folderPath)
    {
        import std.algorithm.setops :  cartesianProduct;
        import std.range : only;
        import std.algorithm.iteration : each, map, joiner;
        import std.array : array;
        import std.format : format;
        import std.file : exists, isFile;

        string[1] paths = [folderPath];
        enum prefixes = ["neg", "pos"];
        enum axes = ["x", "y", "z"];
        enum suffixes = [".bmp", ".exr"];

        size_t side = 0;

        void doStuff(string path)
        {
            if (side > 5)
                return;

            if (path.exists && path.isFile)
            {
                sides[side].loadImage(path);
                sides[side++].decompressGamma_sRGB();
            }
        }

        cartesianProduct(paths[], prefixes, axes, suffixes)
            .map!(tuple => "%s/%s%s%s".format(tuple.expand))
            .each!(doStuff);


        assert (side == 6);
    }

    override void deserialize(const SceneDscNode val, SceneLoadContext context)
    {
        string folder = context.resolveRelativePath(
            context.get!string(val, "folder"));

        this.loadFromFolder(folder);

        import std.stdio;
        writeln(sides);
    }
}

unittest
{
    auto c = new CubemapEnvironment();
    c.loadFromFolder("data/env/forest");
}

