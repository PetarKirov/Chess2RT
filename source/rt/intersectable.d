module rt.intersectable;

import std.typecons : Rebindable;
import rt.importedtypes, rt.ray, rt.geometry;

struct IntersectionData
{
    Ray ray;

    /// intersection point in the world-space
    Vector p;

    alias ip = p;

    /// the normal of the geometry at the intersection point
    Vector normal;

    /// before intersect(): the max dist to look for intersection;
    /// after intersect() - the distance found
    double dist;

    /// 2D UV coordinates for texturing, etc.
    double u, v;

    /// The geometry which was hit
    Rebindable!(const Geometry) g;

    Vector dNdx, dNdy;

    void opAssign(ref const IntersectionData rhs) pure nothrow @nogc @safe
    {
        this.p = rhs.p;
        this.normal = rhs.normal;
        this.dist = rhs.dist;
        this.u = rhs.u;
        this.v = rhs.v;
        this.g = rhs.g;
        this.dNdx = rhs.dNdx;
        this.dNdy = rhs.dNdy;
    }

    int opCmp(ref const IntersectionData rhs) const pure nothrow @nogc @safe
    {
        auto a = this.dist, b = rhs.dist;
        return a < b ? -1 : (a > b);
    }
}

const interface Intersectable
{
    /**
     *  Intersect a geometry with a ray.
     *
     *  Params:
     *      ray = the ray to be traced
     *      data = in the event an intersection is found, it
     *      is filled with info about the intersection point.
     *
     *  Returns:
     *      true if an intersection is found, and it was closer
     *      than the current value of data.dist; otherwise
     *
     *      false if no intersection exists, or it is further than
     *      the current data.dist. In this case, the `data` struct
     *      should remain unchanged.
     *
     *  Note:
     *      The `intersect`` function MUST NOT touch any member of data,
     *      before it can prove the intersection point will be closer
     *      to the current value of `data.dist`!
     *      Also note that this means that if you want to find any
     *      intersection, you must initialize `data.dist` before calling
     *      `intersect`. E.g., if you don't care about distance to intersection,
     *      initialize `data.dist` with `1e99`.
     */
    bool intersect(in Ray ray, ref IntersectionData info) @safe @nogc pure;

    /**
     *  Returns:
     *      true if the given point is "inside" the geometry, for whatever
     *      definition of "inside" is appropriate for the object.
     */
    bool isInside(in Vector p) @safe @nogc pure;
}
