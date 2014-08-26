module rt.intersectable;

import rt.importedtypes, rt.geometry;

struct IntersectionData
{
	/// intersection point in the world-space
	Vector p;
	
	/// the normal of the geometry at the intersection point
	Vector normal; 
	
	/// before intersect(): the max dist to look for intersection; after intersect() - the distance found
	double dist; 
	
	/// 2D UV coordinates for texturing, etc.
	double u, v; 
	
	/// The geometry which was hit
	Geometry g;

	Vector dNdx, dNdy;
}

const interface Intersectable
{
	/**
	 *  @brief Intersect a geometry with a ray.
	 *  Returns true if an intersection is found, and it was closer than the current value of data.dist.
	 * 
	 *  @param ray - the ray to be traced
	 *  @param data - in the event an intersection is found, this is filled with info about the intersection point.
	 *  NOTE: the intersect() function MUST NOT touch any member of data, before it can prove the intersection
	 *        point will be closer to the current value of data.dist!
	 *  Note that this also means that if you want to find any intersection, you must initialize data.dist before
	 *  calling intersect. E.g., if you don't care about distance to intersection, initialize data.dist with 1e99
	 *
	 * @retval true if an intersection is found. The `data' struct should be filled in.
	 * @retval false if no intersection exists, or it is further than the current data.dist. In this case,
	 *         the `data' struct should remain unchanged.
	 */
	bool intersect(const Ray ray, ref IntersectionData info);
	
	
	/// Checks if the given point is "inside" the geometry, for whatever definition of
	/// inside is appropriate for the object. Returns a boolean value accordingly.
	bool isInside(const Vector p);
};


