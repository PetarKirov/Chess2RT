module rt.color;

import std.math;

/// Represents a color, using floating point components in [0..1]
struct Color 
{
	union Rep {
		float components[3];
		float R, G, B;
	}

	Rep rep;
	alias rep this;

	this(float r, float g, float b) //!< Construct a color from floatingpoint values
	{
		setColor(r, g, b);
	}

	this(uint rgbColor) //!< Construct a color from R8G8B8 value like "0xffce08"
	{
		B = (rgbColor & 0xff) / 255.0f;
		G = ((rgbColor >> 8) & 0xff) / 255.0f;
		R = ((rgbColor >> 16) & 0xff) / 255.0f;
	}

	/// convert to RGB32, with channel shift specifications. The default values are for
	/// the blue channel occupying the least-significant byte
	uint toRGB32(int redShift = 16, int greenShift = 8, int blueShift = 0) const
	{
		uint ir = convertTo8bit(R);
		uint ig = convertTo8bit(G);
		uint ib = convertTo8bit(B);
		return (ib << blueShift) | (ig << greenShift) | (ir << redShift);
	}

	/// make black
	void makeZero()
	{
		R = G = B = 0;
	}
	/// set the color explicitly
	void setColor(float r, float g, float b)
	{
		R = r;
		G = g;
		B = b;
	}

	/// get the intensity of the color (direct)
	float intensity() const
	{
		return (R + G + B) / 3;
	}

	/// get the perceptual intensity of the color
	float intensityPerceptual() const
	{
		return cast(float)(R * 0.299 + G * 0.587 + B * 0.114);
	}
	/// Accumulates some color to the current
	void opOpAssign(string op) (const Color rhs) if (op == "+")
	{
		R += rhs.R;
		G += rhs.G;
		B += rhs.B;
	}
	/// multiplies the color
	void opOpAssign(string op) (float multiplier) if (op == "*")
	{
		R *= multiplier;
		G *= multiplier;
		B *= multiplier;
	}
	/// divides the color
	void opOpAssign(string op) (float divider) if (op == "/")
	{
		R /= divider;
		G /= divider;
		B /= divider;
	}
	
	ref inout(float) opIndex(int index) inout
	{
		return components[index];
	}

	Color opBinary(string op)(const Color rhs) if (op == "+" || op == "-" || op == "*")
	{
		return Color(R + rhs.R, G + rhs.G, B + rhs.B);
	}

	Color opBinary(string op)(float f) if (op == "*" || op == "/")
	{
		return Color(R * f, G * f, B * f);
	}

	T opCast(T)() const if (is(T == uint))
	{
		return this.toRGB32();
	}
}

int nearestInt(float x) 
{
	return cast(int)floor(x + 0.5f);
}

ubyte convertTo8bit(float x)
{
	if (x < 0) x = 0;
	if (x > 1) x = 1;
	return cast(ubyte)nearestInt(x * 255.0f);
}

/// checks if two colors are "too different":
bool tooDifferent(const Color lhs, const Color rhs)
{
	const float THRESHOLD = 0.1f;
	return (fabs(lhs.R - rhs.R) > THRESHOLD ||
	        fabs(lhs.G - rhs.G) > THRESHOLD ||
	        fabs(lhs.B - rhs.B) > THRESHOLD);
}

