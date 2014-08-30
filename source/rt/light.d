﻿module rt.light;

import rt.importedtypes;
import rt.color, rt.intersectable, rt.sceneloader;

abstract class Light : Intersectable, Deserializable
{
	Color lightColor;
	float lightPower;

	Color color() const
	{ 
		return lightColor * lightPower;
	}

	bool isInside(const Vector v) const { return false; }

	float solidAngle(const Vector x) const;

	/// get the number of samples this light requires
	size_t getNumSamples() const;
	
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
	void getNthSample(size_t sampleIdx, const Vector shadePos, ref Vector samplePos, ref Color color) const;

	void deserialize(Value val, SceneLoadContext context)
	{
		context.set(this.lightColor, val, "color");
		context.set(this.lightPower, val, "power");
	}
}

class PointLight : Light
{
	Vector pos;

	override size_t getNumSamples() const
	{
		return 1;
	}

	override void getNthSample(size_t sampleIdx, const Vector shadePos, ref Vector samplePos, ref Color color) const
	{
		samplePos = pos;
		color = this.color();
	}

	bool intersect(const Ray ray, ref IntersectionData data) const
	{
		return false; // you can't intersect a point light
	}

	override float solidAngle(const Vector x) const
	{
		return 0;
	}

	override void deserialize(Value val, SceneLoadContext context)
	{
		super.deserialize(val, context);

		context.set(this.pos, val, "pos");
	}
}