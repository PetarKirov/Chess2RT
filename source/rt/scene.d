module rt.scene;

import rt.importedtypes;
import rt.globalsettings, rt.environment, rt.camera,
	rt.node, rt.light, rt.texture, rt.shader, rt.geometry,
	rt.intersectable, rt.color, rt.sceneloader,
	rt.ray;

struct NamedEntities
{
	Light[string] lights;
	Geometry[string] geometries;
	Texture[string] textures;
	Shader[string] shaders;
	Node[string] nodes;

	ref T[string] getArray(T)()
	{
		static if (is(T == Light)) return lights;
		else static if (is(T == Geometry)) return geometries;
		else static if (is(T == Texture)) return textures;
		else static if (is(T == Shader)) return shaders;
		else static if (is(T == Node)) return nodes;
		else static if (is(T == Object)) return other;
		else static assert(0);
	}

	template canBeStored(T)
	{
	    import std.traits, std.typetuple;

	    enum isDerivedFromT(Other) = isImplicitlyConvertible!(Other, T);
	    enum canBeStored = anySatisfy!(isDerivedFromT,
									   Light, Geometry, Texture, Shader, Node);
	}
}

class Scene
{
	GlobalSettings settings;
	Environment environment;
	Camera camera;

	Light[] lights;
	Geometry[] geometries;
	Texture[] textures;
	Shader[] shaders;
	Node[] nodes;

	NamedEntities namedEntities;

	/// Notifies the scene so that a new frame is about to begin.
	/// It calls the beginFrame() method of all scene elements
	void beginFrame()
	{	 
	  camera.beginFrame();
	}

	/// checks for visibility between points `from' and `to'
	/// (from is assumed to be near a surface, whereas to is near a light)s
	bool testVisibility(const Vector from, const Vector to) const
	{
		Ray ray;
		ray.orig = from;
		ray.dir = to - from;
		ray.dir.normalize();
		ray.flags |= RayFlags.RF_SHADOW;
		
		IntersectionData temp;
		temp.dist = (to - from).length();
		
		foreach (node; nodes)
			if (node.intersect(ray, temp))
				return false;
		
		return true;
	}
}

@disable
Color Raytrace(Ray ray)
{		
	IntersectionData data;
	Node closestNode;
	
	//version (debug)
	//cout << "  Raytrace[start = " << ray.start << ", dir = " << ray.dir << "]\n";
	
	data.dist = 1e99;

	Node[] nodes;

	foreach (node; nodes)
		if (node.geom.intersect(ray, data))
			closestNode = node;
	
	if (!closestNode)
		return Color(0, 0, 0);
	
	//version(debug) {
	//cout << "    Hit " << closestNode->geom->getName() << " at distance " << fixed << setprecision(2) << data.dist << endl;
	//cout << "      Intersection point: " << data.p << endl;
	//cout << "      Normal:             " << data.normal << endl;
	//cout << "      UV coods:           " << data.u << ", " << data.v << endl;
	//}
	
	return closestNode.shader.shade(ray, data);
}