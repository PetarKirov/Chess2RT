module rt.shader;

import std.random, std.json;
import rt.importedtypes;
import rt.scene, rt.texture, rt.color, rt.intersectable, rt.ray;
import rt.sceneloader;

interface BRDF
{
	Color eval(const IntersectionData x, const Ray w_in, const Ray w_out);
	
	void spawnRay(const IntersectionData x, const Ray w_in,
	              ref Ray w_out, ref Color colorEval, ref float pdf);
};

interface IShader
{	
	Color shade(const Ray ray, const IntersectionData data);
};

abstract class Shader : IShader, BRDF, JsonDeserializer
{
	Color color;
	Scene scene;

	string name;

	this()
	{

	}

	this(const Color color)
	{
		this.color = color;
	}
}

/// A Lambert (flat) shader
class Lambert : Shader
{
	/// A diffuse texture, if not NULL.
	Texture texture; 

	this() { this(Color(1, 1, 1)); }

	this(const Color diffuseColor = Color(1, 1, 1), Texture texture = null)
	{
		super(diffuseColor);
		this.texture = texture;
	}

	Color shade(const Ray ray, const IntersectionData data)
	{
		import std.stdio;
		writeln(data.u, data.v);

		// turn the normal vector towards us (if needed):
		Vector N = faceforward(ray.dir, data.normal);
		
		// fetch the material color. This is ether the solid color, or a color
		// from the texture, if it's set up.
		Color diffuseColor = this.color;
		if (texture)
			diffuseColor = texture.getTexColor(ray, data.u, data.v, N);
		
		Color lightContrib = scene.settings.ambientLight;

		foreach(light; scene.lights) {
		//for (int i = 0; i < (int) scene.lights.size(); i++) {
			int numSamples = light.getNumSamples();
			auto avgColor = Color(0, 0, 0);
			for (int j = 0; j < numSamples; j++) {
				Vector lightPos;
				Color lightColor;
				light.getNthSample(j, data.p, lightPos, lightColor);
				if (lightColor.intensity() != 0 && scene.testVisibility(data.p + N * 1e-6, lightPos)) {
					Vector lightDir = lightPos - data.p;
					lightDir.normalize();
					
					// get the Lambertian cosine of the angle between the geometry's normal and
					// the direction to the light. This will scale the lighting:
					double cosTheta = dot(lightDir, N);
					if (cosTheta > 0)
						avgColor += lightColor / (data.p - lightPos).squaredLength() * cosTheta;
				}
			}
			lightContrib += avgColor / numSamples;
		}
		return diffuseColor * lightContrib;
	}

	Color eval(const IntersectionData x, const Ray w_in, const Ray w_out)
	{
		Vector N = faceforward(w_in.dir, x.normal);
		Color diffuseColor = this.color;

		if (texture)
			diffuseColor = texture.getTexColor(w_in, x.u, x.v, N);

		return diffuseColor * (1 / PI) * max(0.0, dot(w_out.dir, N));
	}
	
	void spawnRay(const IntersectionData x, const Ray w_in, 
	              ref Ray w_out, ref Color colorEval, ref float pdf)
	{
		Vector N = faceforward(w_in.dir, x.normal);
		Color diffuseColor = this.color;

		if (texture)
			diffuseColor = texture.getTexColor(w_in, x.u, x.v, N);

		w_out = w_in;
		
		w_out.depth++;
		w_out.orig = x.p + N * 1e-6;
		w_out.dir = hemisphereSample(N);
		w_out.flags = w_out.flags | RayFlags.RF_DIFFUSE;
		colorEval = diffuseColor * (1 / PI) * max(0.0, dot(w_out.dir, N));
		pdf = 1 / (2 * PI);
	}

	void loadFromJson(JSONValue json, SceneLoadContext context)
	{
		string t;
		context.set(t, json, "texture");

		import std.stdio;
		writeln(context.textures);

		this.texture = context.textures[t];
	}
};

Vector hemisphereSample(const Vector normal)
{	
	double u = uniform(0.0, 1.0);
	double v = uniform(0.0, 1.0);
	
	double theta = 2 * PI * u;
	double phi = acos(2 * v - 1) - PI/2;
	
	auto res = Vector(cos(theta) * cos(phi),
	                  sin(phi),
					  sin(theta) * cos(phi));
	
	if (dot(res, normal) < 0)
		res = -res;

	return res;
}