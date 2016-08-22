module rt.ray;

public import rt.importedtypes : Vector;

/// Flags that mark a ray in some way, so the behaviour of the raytracer can be altered.
enum RayFlags
{
    None    = 0,

    /// The ray is a debug one (launched from a mouse-click on the rendered image).
    /// raytrace() prints diagnostics when it encounters such a ray.
    Debug    = 1,

    /// The ray is a shadow ray. This hints the raytracer to skip some calculations
    /// (since the IntersectionData won't be used for shading), and to disable backface culling
    /// for Mesh objects.
    Shadow   = 2,

    /// The ray has hit some glossy surface somewhere along the way.
    /// so if it meets a new glossy surface, it can safely use lower sampling settings.
    Glossy   = 4,

    /// last constituent of a ray path was a diffuse surface
    Diffuse  = 8,
};

struct Ray
{
    Vector orig, dir;

    debug
    {
        RayFlags flags = RayFlags.Debug;
    }
    else
    {
        RayFlags flags = RayFlags.None;
    }


    int depth;

    @property bool isDebug() const pure nothrow @safe @nogc
    {
        bool result = (this.flags & RayFlags.Debug) != 0;

        uint a = flags;
        return result;
    }

    @property void isDebug(bool newVal) pure nothrow @safe @nogc
    {
        uint a = flags;

        if (newVal)
            flags |= RayFlags.Debug;
        else
            flags &= ~RayFlags.Debug;

        a = flags;
    }
}

Ray project(Ray v, int a, int b, int c) pure nothrow @safe @nogc
{
    static import rt.importedtypes;
    v.orig = rt.importedtypes.project(v.orig, a, b, c);
    v.dir = rt.importedtypes.project(v.dir, a, b, c);
    return v;
}
