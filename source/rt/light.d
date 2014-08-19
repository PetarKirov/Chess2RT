module rt.light;

import std.json;
import rt.importedtypes;
import rt.color, rt.intersectable, rt.sceneloader;

abstract class Light : Intersectable, JsonDeserializer
{
	Color lightColor;
	float lightPower;

	string name;

	Color color() const
	{ 
		return lightColor * lightPower;
	}

	bool isInside(const Vector v) { return false; }

	float solidAngle(const Vector x);

	/// get the number of samples this light requires (must be strictly positive)
	int getNumSamples();
	
	/**
	 * Gets the n-th sample
	 * 
	 * Params:
	 * 	sampleIdx = a sample index: 0 <= sampleIdx < getNumSamples().
	 * 	shadePos = the point we're shading. Can be used to modulate light power if the light doesn't shine eqeually in all directions.
	 * 	samplePos = [out] the generated light sample position
	 * 	color = [out] the generated light "color". This is usually has large components (i.e.,
	 *                      it's base color * power
	 */
	void getNthSample(int sampleIdx, const Vector shadePos, ref Vector samplePos, ref Color color);

	void loadFromJson(JSONValue json, SceneLoadContext context)
	{
		context.set(this.lightColor, json, "color");
		context.set(this.lightPower, json, "power");
	}
}

class PointLight : Light
{
	Vector pos;

	override int getNumSamples()
	{
		return 1;
	}

	override void getNthSample(int sampleIdx, const Vector shadePos, ref Vector samplePos, ref Color color)
	{
		samplePos = pos;
		color = this.color();
	}

	bool intersect(const Ray ray, ref IntersectionData data)
	{
		return false; // you can't intersect a point light
	}

	override float solidAngle(const Vector x)
	{
		return 0;
	}

	override void loadFromJson(JSONValue json, SceneLoadContext context)
	{
		super.loadFromJson(json, context);

		context.set(this.pos, json, "pos");
	}
}