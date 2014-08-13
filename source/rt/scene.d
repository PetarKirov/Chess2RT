module rt.scene;

import rt.importedtypes;
import rt.color, rt.camera, rt.node, rt.light, rt.geometry;

class Scene
{
	Camera camera;
	Node[] nodes;
	Light[] lights;
	
	Color ambientLight;

	/// checks for visibility between points `from' and `to'
	/// (from is assumed to be near a surface, whereas to is near a light)s
	bool testVisibilitytestVisibility(const Vector from, const Vector to)
	{
		Ray ray;
		ray.orig = from;
		ray.dir = to - from;
		ray.dir.normalize();
		
		IntersectionData temp;
		temp.dist = (to - from).length();

		foreach (node; nodes)
			if (node.geom.intersect(ray, temp))
				return false;
		
		return true;
	}

	Color Raytrace(Ray ray)
	{		
		IntersectionData data;
		Node closestNode = null;
		
		//version (debug)
			//cout << "  Raytrace[start = " << ray.start << ", dir = " << ray.dir << "]\n";
		
		data.dist = 1e99;
		
		foreach (node; nodes)
			if (node.geom.intersect(ray, data))
				closestNode = node;
		
		if (!closestNode) return Color(0, 0, 0);
		
		//version(debug) {
			//cout << "    Hit " << closestNode->geom->getName() << " at distance " << fixed << setprecision(2) << data.dist << endl;
			//cout << "      Intersection point: " << data.p << endl;
			//cout << "      Normal:             " << data.normal << endl;
			//cout << "      UV coods:           " << data.u << ", " << data.v << endl;
		//}
		
		return closestNode.shader.shade(ray, data);
	}
}