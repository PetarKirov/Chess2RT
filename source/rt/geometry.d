module rt.geometry;

import rt.importedtypes, rt.intersectable, rt.sceneloader;
import std.json;

abstract class Geometry : Intersectable, JsonDeserializer
{
	string name;
}

class Plane: Geometry
{
	/// Y-intercept. The plane is parallel to XZ, the y-intercept is at this value
	double y; 
	double limit;

	this() { }

	this(double _y = 0, double _limit = 1e99) { y = _y; limit = _limit; }

	bool isInside(const Vector p) const { return false; }

	bool intersect(const Ray ray, ref IntersectionData data)
	{
		// intersect a ray with a XZ plane:
		// if the ray is pointing to the horizon, or "up", but the plane is below us,
		// of if the ray is pointing down, and the plane is above us, we have no intersection
		if ((ray.orig.y > y && ray.dir.y > -1e-9) || (ray.orig.y < y && ray.dir.y < 1e-9))
			return false;
		else
		{
			double yDiff = ray.dir.y;
			double wantYDiff = ray.orig.y - this.y;
			double mult = wantYDiff / -yDiff;

			// if the distance to the intersection (mult) doesn't optimize our current distance, bail out:
			if (mult > data.dist) return false;
			
			Vector p = ray.orig + ray.dir * mult;
			if (fabs(p.x) > limit || fabs(p.z) > limit) return false;
			
			// calculate intersection:
			data.p = p;
			data.dist = mult;
			data.normal = Vector(0, 1, 0);
			data.dNdx = Vector(1, 0, 0);
			data.dNdy = Vector(0, 0, 1);
			data.u = data.p.x;
			data.v = data.p.z;
			data.g = this;

			return true;
		}
	}

	void loadFromJson(JSONValue json, SceneLoadContext context)
	{
		context.set(this.y, json, "y");
	}
}