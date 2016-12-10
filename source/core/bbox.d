///
module core.bbox;

import rt.importedtypes : Vector, cross, dot, signOf;
import rt.ray;
import core.axis : Axis;

import std.math;

@safe @nogc pure nothrow
bool intersectTriangleFast(in ref Ray ray, in ref Vector A, in ref Vector B, in ref Vector C, ref double dist)
{
    Vector AB = B - A;
    Vector AC = C - A;
    Vector D = -ray.dir;
    //              0               A
    Vector H = ray.orig - A;

    /* 2. Solve the equation:
     *
     * A + lambda2 * AB + lambda3 * AC = ray.start + gamma * ray.dir
     *
     * which can be rearranged as:
     * lambda2 * AB + lambda3 * AC + gamma * D = ray.start - A
     *
     * Which is a linear system of three rows and three unknowns, which we solve using Carmer's rule
     */

    // Find the determinant of the left part of the equation:
    Vector ABcrossAC = cross(AB, AC);
    double Dcr = dot(ABcrossAC, D);

    // are the ray and triangle parallel?
    if (fabs(Dcr) < 1e-12) return false;

    double lambda2 = dot(cross(H,  AC), D) / Dcr;
    double lambda3 = dot(cross(AB,  H), D) / Dcr;
    double gamma   = dot(ABcrossAC, H)     / Dcr;

    // is intersection behind us, or too far?
    if (gamma < 0 || gamma > dist) return false;

    // is the intersection outside the triangle?
    if (lambda2 < 0 || lambda2 > 1 || lambda3 < 0 || lambda3 > 1 || lambda2 + lambda3 > 1)
        return false;

    dist = gamma;

    return true;
}

/// Ray with rdir that's used for quicker intersection tests.
struct RRay
{
	Ray ray;
	Vector rdir;

    alias ray this;

	this(Ray r) @safe @nogc pure nothrow { this.ray = r; }

	void prepareForTracing() @safe @nogc pure nothrow
	{
		rdir.x = fabs(ray.dir.x) > 1e-12 ? 1.0 / ray.dir.x : 1e12;
		rdir.y = fabs(ray.dir.y) > 1e-12 ? 1.0 / ray.dir.y : 1e12;
		rdir.z = fabs(ray.dir.z) > 1e-12 ? 1.0 / ray.dir.z : 1e12;
	}
}


/**
 * Axis-aligned bounding box around some object
 *
 * A BBox is the volume, bounded by the vectors min, max, such that
 * any point p inside the volume satisfies:
 * min.x <= p.x <= max.x, min.y <= p.y <= max.y and
 * min.z <= p.z <= max.z.
 */
struct BBox
{
    @safe @nogc pure nothrow:

    Vector min, max;

    enum emptyBox = BBox(Vector(double.infinity), Vector(-double.infinity));

    /**
	 * Adds a point to the bounding box, possibly expanding it.
     *
     * If the point is inside the current box, nothing happens.
     * If it is outside, the box grows just enough so that in
     * encompasses the new point.
     */
    void add(in ref Vector vec)
    {
        min.x = fmin(min.x, vec.x); max.x = fmax(max.x, vec.x);
        min.y = fmin(min.y, vec.y); max.y = fmax(max.y, vec.y);
        min.z = fmin(min.z, vec.z); max.z = fmax(max.z, vec.z);
    }

    /// Checks if a point is inside the bounding box (borders-inclusive).
    bool inside(in ref Vector v) const
    {
		enum delta = 1e-6;
        return (min.x - delta <= v.x && v.x <= max.x + delta &&
                min.y - delta <= v.y && v.y <= max.y + delta &&
                min.z - delta <= v.z && v.z <= max.z + delta);
    }

    /// Returns: true if an intersection exists, false otherwise.
    bool testIntersect(in ref RRay ray) const
    {
        if (inside(ray.orig))
            return true;

        for (int dim = 0; dim < 3; dim++)
        {
            if ((ray.dir[dim] < 0 && ray.orig[dim] < min[dim]) || (ray.dir[dim] > 0 && ray.orig[dim] > max[dim])) continue;
            if (fabs(ray.dir[dim]) < 1e-9) continue;
            double mul = ray.rdir[dim];
            int u = (dim == 0) ? 1 : 0;
            int v = (dim == 2) ? 1 : 2;
            double dist, x, y;
            dist = (min[dim] - ray.orig[dim]) * mul;
            if (dist < 0) continue; //*
            /* (*) this is a good optimization I found out by chance. Consider the following scenario
             *
             *   ---+  ^  (ray)
             *      |   \
             * bbox |    \
             *      |     \
             *      |      * (camera)
             * -----+
             *
             * if we're considering the walls up and down of the bbox (which belong to the same axis),
             * the optimization in (*) says that we can skip testing with the "up" wall, if the "down"
             * wall is behind us. The rationale for that is, that we can never intersect the "down" wall,
             * and even if we have the chance to intersect the "up" wall, we'd be intersection the "right"
             * wall first. So we can just skip any further intersection tests for this axis.
             * This may seem bogus at first, as it doesn't work if the camera is inside the BBox, but then we would
             * have quitted the function because of the inside(ray.orig) condition in the first line of the function.
             */
            x = ray.orig[u] + ray.dir[u] * dist;
            if (min[u] <= x && x <= max[u]) {
                y = ray.orig[v] + ray.dir[v] * dist;
                if (min[v] <= y && y <= max[v]) {
                    return true;
                }
            }
            dist = (max[dim] - ray.orig[dim]) * mul;
            if (dist < 0) continue;
            x = ray.orig[u] + ray.dir[u] * dist;
            if (min[u] <= x && x <= max[u]) {
                y = ray.orig[v] + ray.dir[v] * dist;
                if (min[v] <= y && y <= max[v]) {
                    return true;
                }
            }
        }
        return false;
    }

	/**
     *  Returns the distance to the closest intersection of the ray and the
	 *  BBox, or +inf if such an intersection doesn't exist.
	 *
     *  Note:
	 * 		This is heavier than using just testIntersect() - testIntersect
     *      only needs to consider *any* intersection, whereas
	 *      closestIntersection() also needs to find the nearest one.
     */
    double closestIntersection(in ref RRay ray) const
    {
        if (inside(ray.orig)) return 0;
        double minDist = double.infinity;
        for (int dim = 0; dim < 3; dim++) {
            if ((ray.dir[dim] < 0 && ray.orig[dim] < min[dim]) || (ray.dir[dim] > 0 && ray.orig[dim] > max[dim])) continue;
            if (fabs(ray.dir[dim]) < 1e-9) continue;
            double mul = ray.rdir[dim];
            double[2] xs = [ min[dim], max[dim] ];
            int u = (dim == 0) ? 1 : 0;
            int v = (dim == 2) ? 1 : 2;
            for (int j = 0; j < 2; j++) {
                double dist = (xs[j] - ray.orig[dim]) * mul;
                if (dist < 0) continue;
                double x = ray.orig[u] + ray.dir[u] * dist;
                if (min[u] <= x && x <= max[u]) {
                    double y = ray.orig[v] + ray.dir[v] * dist;
                    if (min[v] <= y && y <= max[v]) {
                        minDist = fmin(minDist, dist);
                    }
                }
            }
        }
        return minDist;
    }

    /// Check whether the box intersects a triangle (all three cases)
    bool intersectTriangle(in ref Vector A, in ref Vector B, in ref Vector C) const
    {
        if (inside(A) || inside(B) || inside(C)) return true;
        RRay ray;
        Vector[3] t = [ A, B, C ];
        for (int i = 0; i < 3; i++)
        for (int j = i + 1; j < 3; j++) {
            ray.orig = t[i];
            ray.dir = t[j] - t[i];
            ray.prepareForTracing();
            if (testIntersect(ray)) {
                ray.orig = t[j];
                ray.dir = t[i] - t[j];
                ray.prepareForTracing();
                if (testIntersect(ray)) return true;
            }
        }
        Vector AB = B - A;
        Vector AC = C - A;
        Vector ABcrossAC = cross(AB, AC);

        double D = dot(A, ABcrossAC);
        for (int mask = 0; mask < 7; mask++) {
            for (int j = 0; j < 3; j++) {
                if (mask & (1 << j)) continue;
                ray.orig = Vector((mask & 1) ? max.x : min.x, (mask & 2) ? max.y : min.y, (mask & 4) ? max.z : min.z);
                Vector rayEnd = ray.orig;
                rayEnd[j] = max[j];
                if (signOf(dot(ray.orig, ABcrossAC) - D) != signOf(dot(rayEnd, ABcrossAC) - D)) {
                    ray.dir = rayEnd - ray.orig;
                    ray.prepareForTracing();
                    double gamma = 1.0000001;
                    if (intersectTriangleFast(ray, A, B, C, gamma)) return true;
                }
            }
        }
        return false;
    }

    /** Split a bounding box along an given axis at a given position,
	 *  yielding a two child bboxes.
     *
     *  Params:
	 *  	axis = an axis to use for splitting
	 *  	where = where to put the splitting plane (must be between min[axis] and max[axis])
	 *  	left = output - this is where the left bbox is stored (lower coordinates)
	 *  	output = this is where the right bbox is stored.
     */
    void split(Axis axis, double where, out BBox left, out BBox right) const
    {
        left = this;
        right = this;
        left.max[axis] = where;
        right.min[axis] = where;
    }

	/**
     *  Checks if a ray intersects a single wall inside the BBox.
     *
     *  Consider the intersection of the splitting plane as described in split(), and the BBox
     *  (i.e., the "split wall"). We want to check if the ray intersects that wall.
     */
    bool intersectWall(Axis axis, double where, in ref RRay ray) const
    {
    	if (fabs(ray.dir[axis]) < 1e-9)
	    	return (fabs(ray.orig[axis] - where) < 1e-9);

		int u = (axis == 0) ? 1 : 0;
		int v = (axis == 2) ? 1 : 2;
		double toGo = where - ray.orig[axis];
		double rdirInAxis = ray.rdir[axis];

		// check if toGo and dirInAxis are of opposing signs:
		if (toGo * rdirInAxis < 0)
			return false;

		double d = toGo * rdirInAxis;
		double tu = ray.orig[u] + ray.dir[u] * d;

		if (min[u] <= tu && tu <= max[u])
		{
			double tv = ray.orig[v] + ray.dir[v] * d;
			return (min[v] <= tv && tv <= max[v]);
		}
		else
			return false;
	}
}
