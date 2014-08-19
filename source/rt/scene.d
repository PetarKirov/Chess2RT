module rt.scene;

import rt.importedtypes;
import rt.globalSettings, rt.environment, rt.camera,
	rt.node, rt.light, rt.texture, rt.shader, rt.geometry, rt.intersectable, rt.color, rt.sceneloader;
import std.json;

class Scene
{
	GlobalSettings settings;
	Environment environment;
	Camera camera;

	Node[] nodes;
	Light[] lights;
	Texture[] textures;
	Shader[] shaders;
	Geometry[] geometries;

	/// Notifies the scene so that a render is about to begin.
	/// It calls the beginRender() method of all scene elements
	void beginRender()
	{
//		foreach(node; nodes) node.beginRender();
//		foreach(light; lights) light.beginRender();
//		foreach(texture; textures) texture.beginRender();
//
//		environment.beginRender();
//		camera.beginRender();
	}

	/// Notifies the scene so that a new frame is about to begin.
	/// It calls the beginFrame() method of all scene elements
	void beginFrame()
	{
//		foreach(node; nodes) node.beginFrame();
//		foreach(light; lights) light.beginFrame();
//		foreach(texture; textures) texture.beginFrame();
//		
//		environment.beginFrame();
//		camera.beginFrame();
	}

	/// checks for visibility between points `from' and `to'
	/// (from is assumed to be near a surface, whereas to is near a light)s
	bool testVisibility(const Vector from, const Vector to)
	{
		Ray ray;
		ray.orig = from;
		ray.dir = to - from;
		ray.dir.normalize();
		
		IntersectionData temp;
		temp.dist = (to - from).length();
		
		foreach (node; nodes)
			if (node.intersect(ray, temp))
				return false;
		
		return true;
	}
}

Scene loadFromJson(JSONValue json, SceneLoadContext context)
{
	Scene scene = new Scene();

	context.set(scene.settings, json, "GlobalSettings");
	context.set(scene.camera, json, "Camera");
	context.set(scene.lights, json, "Lights");
	context.set(scene.geometries, json, "Geometries");
	context.set(scene.textures, json, "Textures");
	context.set(scene.shaders, json, "Shaders");
	context.set(scene.nodes, json, "Nodes");

	return scene;
}




@disable
Color Raytrace(Ray ray)
{		
	IntersectionData data;
	Node closestNode = null;
	
	//version (debug)
	//cout << "  Raytrace[start = " << ray.start << ", dir = " << ray.dir << "]\n";
	
	data.dist = 1e99;

	Node[] nodes;

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