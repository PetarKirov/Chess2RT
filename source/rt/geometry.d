module rt.geometry;

import std.algorithm : sort;
import std.range : chain;
import std.typecons : Rebindable;
import rt.importedtypes, rt.intersectable, rt.sceneloader, util.array;

abstract class Geometry : Intersectable, Deserializable
{
	void toString(scope void delegate(const(char)[]) sink) const
	{
	}
}

class Plane : Geometry
{
	/// Y-intercept. The plane is parallel to XZ, the y-intercept is at this value
	double y; 
	double limit;

	this() { }

	this(double _y = 0, double _limit = 1e99) { y = _y; limit = _limit; }

	bool isInside(in Vector p) const @nogc
	{
		return false;
	}

	bool intersect(in Ray ray, ref IntersectionData data) const @nogc
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

	void deserialize(Value val, SceneLoadContext context)
	{
		context.set(this.y, val, "y");
	}

	override void toString(scope void delegate(const(char)[]) sink) const
	{
		import util.prettyPrint;
		mixin(toStrBody);
	}
}

class Sphere : Geometry
{
	private
	{
		Vector center;
		double R;
	}

	this()
	{
		this(Vector(0, 0, 0), 1);
	}

	this(const Vector center, double R)
	{
		this.center = center;
		this.R = R;
	}

	bool intersect(in Ray ray, ref IntersectionData info) const @nogc
	{
		// compute the sphere intersection using a quadratic equation:
		Vector H = ray.orig - center;
		double A = ray.dir.squaredLength();
		double B = 2 * dot(H, ray.dir);
		double C = H.squaredLength() - R * R;
		double Dscr = B*B - 4 * A * C;

		if (Dscr < 0)
			return false; // no solutions to the quadratic equation - then we don't have an intersection.

		double x1 = (-B + sqrt(Dscr)) / (2*A);
		double x2 = (-B - sqrt(Dscr)) / (2*A);
		double sol = x2; // get the closer of the two solutions...
		if (sol < 0) sol = x1; // ... but if it's behind us, opt for the other one
		if (sol < 0) return false; // ... still behind? Then the whole sphere is behind us - no intersection.
		
		// if the distance to the intersection doesn't optimize our current distance, bail out:
		if (sol > info.dist)
			return false;
		
		info.dist = sol;
		info.p = ray.orig + ray.dir * sol;
		info.normal = info.p - center; // generate the normal by getting the direction from the center to the ip
		info.normal.normalize();
		double angle = atan2(info.p.z - center.z, info.p.x - center.x);
		info.u = (PI + angle)/(2*PI);
		info.v = 1.0 - (PI/2 + asin((info.p.y - center.y)/R)) / PI;
		info.dNdx = Vector(cos(angle + PI/2), 0, sin(angle + PI/2));
		info.dNdy = info.dNdx.cross(info.normal);
		info.g = this;
		return true;
	}

	bool isInside(in Vector p) const @nogc
	{
		return (center - p).squaredLength() < R * R;
	}
	
	void deserialize(Value val, SceneLoadContext context)
	{
		bool centerSet = context.set(this.center, val, "center");

		if (!centerSet)
			this.center = Vector(0f, 0f, 0f);

		context.set(this.R, val, "R");
	}

	override void toString(scope void delegate(const(char)[]) sink) const
	{
		import util.prettyPrint;
		mixin(toStrBody);
	}
}

class Cube : Geometry
{
	Vector center;
	double side;

	this()
	{
		this(Vector(0, 0, 0), 1);
	}

	this(const Vector center, double side)
	{
		this.center = center;
		this.side = side;
	}

	bool isInside(const Vector p) const @nogc
	{
		return (fabs(p.x - center.x) <= side * 0.5 &&
		        fabs(p.y - center.y) <= side * 0.5 &&
		        fabs(p.z - center.z) <= side * 0.5);
	}

	bool intersect(in Ray ray, ref IntersectionData data) const @nogc
	{
		// check for intersection with the negative Y and positive Y sides
		bool found = intersectCubeSide(ray, center, data);
		
		// check for intersection with the negative X and positive X sides
		if (intersectCubeSide(project(ray, 1, 0, 2), project(center, 1, 0, 2), data))
		{
			found = true;
			data.normal = unproject(data.normal, 1, 0, 2);
			data.p = unproject(data.p, 1, 0, 2);
		}
		
		// check for intersection with the negative Z and positive Z sides
		if (intersectCubeSide(project(ray, 0, 2, 1), project(center, 0, 2, 1), data))
		{
			found = true;
			data.normal = unproject(data.normal, 0, 2, 1);
			data.p = unproject(data.p, 0, 2, 1);
		}

		if (found)
			data.g = this;

		return found;
	}

	private bool intersectCubeSide(in Ray ray, in Vector center, ref IntersectionData data) const @nogc
	{
		if (fabs(ray.dir.y) < 1e-9)
			return false;
		
		double halfSide = this.side * 0.5;
		bool found = false;

		for (int side = -1; side <= 1; side += 2)
		{
			double yDiff = ray.dir.y;
			double wantYDiff = ray.orig.y - (center.y + side * halfSide);
			double mult = wantYDiff / -yDiff;

			if (mult < 0) continue;
			if (mult > data.dist) continue;

			Vector p = ray.orig + ray.dir * mult;

			if (p.x < center.x - halfSide ||
			    p.x > center.x + halfSide ||
			    p.z < center.z - halfSide ||
			    p.z > center.z + halfSide)
				continue;

			data.p = ray.orig + ray.dir * mult;
			data.dist = mult;
			data.normal = Vector(0, side, 0);
			data.dNdx = Vector(1, 0, 0);
			data.dNdy = Vector(0, 0, side);
			data.u = data.p.x - center.x;
			data.v = data.p.z - center.z;
			found = true;	
		}

		return found;
	}

	void deserialize(Value val, SceneLoadContext context)
	{
		context.set(this.center, val, "center");
		context.set(this.side, val, "side");
	}

	override void toString(scope void delegate(const(char)[]) sink) const
	{
		import util.prettyPrint;
		mixin(toStrBody);
	}
}

abstract class CsgOp : Geometry
{
	protected
	{
		Rebindable!(const Geometry) left;
		Rebindable!(const Geometry) right;
	}

	this()
	{
		this(null, null);
	}

	this(Geometry left, Geometry right)
	{
		this.left = left;
		this.right = right;
	}

	bool boolOp(bool inLeft, bool inRight) const @nogc;

	void findAllIntersections(const Geometry geom, Ray ray, ref MyArray!IntersectionData l) const @nogc
	{
		double currentLength = 0;
		
		while (true)
		{
			IntersectionData temp;
			temp.dist = 1e99;
			
			if (!geom.intersect(ray, temp))
				break;

			temp.dist += currentLength;
			currentLength = temp.dist;

			ray.orig = temp.p + ray.dir * 1e-6;

			l ~= temp;
		}
	}

	bool intersect(in Ray ray, ref IntersectionData data) const @nogc
	{
		alias ID = IntersectionData;

		MyArray!ID leftData, rightData, allData;

		findAllIntersections(left, ray, leftData);
		findAllIntersections(right, ray, rightData);

		foreach(elem; chain(leftData[], rightData[]))
			allData ~= elem;

		import std.c.stdlib : qsort;

		mySort(allData.data);

		// if we have an even number of intersections -> we're outside the object. If odd, we're inside:
		bool inL, inR;
		inL = leftData.length % 2 == 1;
		inR = rightData.length % 2 == 1;
		
		foreach (current; allData[])
		{			
			// at each intersection, we flip the `insidedness' of one of the two variables:
			if (&current.g == &left)
				inL = !inL;
			else
				inR = !inR;
			
			// if we entered the CSG just now, and this optimizes the current data.dist ->
			// then we've found the intersection.
			if (boolOp(inL, inR))
			{
				if (current.dist > data.dist)
					return false;

				data = current;
				return true;
			}
		}

		return false;
	}	

	bool isInside(const Vector p) const @nogc
	{
		return boolOp(left.isInside(p), right.isInside(p));
	}

	void deserialize(Value val, SceneLoadContext context)
	{
		string geomName;

		context.set(geomName, val, "left");
		this.left = context.named.geometries[geomName];

		context.set(geomName, val, "right");
		this.right = context.named.geometries[geomName];
	}

	override void toString(scope void delegate(const(char)[]) sink) const
	{
		import util.prettyPrint;
		mixin(toStrBody);
	}
}

void mySort(IntersectionData[] arr) @nogc
{
	long n = arr.length;

	int i,j;
	int iMin;

	for (j = 0; j < n-1; j++) {
		/* find the min element in the unsorted a[j .. n-1] */
		
		/* assume the min is the first element */
		iMin = j;
		/* test against elements after j to find the smallest */
		for ( i = j+1; i < n; i++) {
			/* if this element is less, then it is the new minimum */  
			if (arr[i].dist < arr[iMin].dist) {
				/* found new minimum; remember its index */
				iMin = i;
			}
		}
		
		if(iMin != j) {
			import std.algorithm : swap;
			swap(arr[j], arr[iMin]);
		}
		
	}
}


class CsgUnion : CsgOp
{
	this() { }

	override bool boolOp(bool inLeft, bool inRight) const @nogc
	{
		return inLeft || inRight;
	}
}

class CsgInter : CsgOp
{
	this() { }

	override bool boolOp(bool inLeft, bool inRight) const @nogc
	{
		return inLeft && inRight;
	}
}

class CsgDiff : CsgOp
{
	this() { }

	/// Overrides the generic intersector to handle a corner case
	override bool intersect(in Ray ray, ref IntersectionData data) const @nogc
	{
		if (!super.intersect(ray, data)) return false;
		/*
		* Consider the following CsgDiff: a larger sphere with a smaller sphere somewhere on its side
		* The result is the larger sphere, with some "eaten out" part. The question is:
		* Where should the normals point, in the surface of the "eaten out" parts?
		* These normals are generated by the smaller sphere, and point to the inside of the interior of
		* the larger. They are obviously wrong.
		*
		* Solution: when we detect a situation like this, we flip the normals.
		*/
		if (right.isInside(data.p - ray.dir * 1e-6) != right.isInside(data.p + ray.dir * 1e-6))
			data.normal = -data.normal;
		return true;
	}
	
	override bool boolOp(bool inLeft, bool inRight) const @nogc
	{
		return inLeft && !inRight;
	}
};
