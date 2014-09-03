module rt.texture;

import rt.importedtypes, rt.intersectable, rt.color, rt.sceneloader;

abstract class Texture : Deserializable
{
	Color getTexColor(const Ray ray, double u, double v, Vector normal) const;

	void modifyNormal(IntersectionData data) const
	{
	}
}

/// A checker texture
class Checker: Texture
{
	Color color1, color2; /// the colors of the alternating squares
	double size; /// the size of a square side, in world units

	this() { this(Color(0, 0, 0)); }

	this(const Color color1 = Color(0, 0, 0),
	     const Color color2 = Color(1, 1, 1),
		 double size = 1.0)
	{
		this.color1 = color1;
		this.color2 = color2;
		this.size = size;
	}

	override Color getTexColor(const Ray ray, double u, double v, Vector normal) const
	{
		/*
		 * The checker texture works like that. Partition the whole 2D space
		 * in squares of squareSize. Use division and floor()ing to get the
		 * integral coordinates of the square, which our point happens to be. Then,
		 * use the parity of the sum of those coordinates to decide which color to return.
		*/

		// example - u = 150, v = -230, size = 100
		// -> 1, -3
		import std.conv;

		int x = to!int(floor(u / size));
		int y = to!int(floor(v / size));

		int white = (x + y) % 2;

		return white ? color2 : color1;
	}

	void deserialize(Value val, SceneLoadContext context)
	{
		context.set(this.color1, val, "color1");
		context.set(this.color2, val, "color2");
		context.set(this.size, val, "size");
	}

	override string toString() const
	{
		import std.string;
		
		return format("%s %s %s", color1, color2, size);
	}
}