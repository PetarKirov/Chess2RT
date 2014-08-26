module rt.color;

import std.math;

/// Represents a color, using floating point components in [0..1]
struct Color 
{
	union Rep {
		float components[3];
		struct { float r, g, b;	}
	}

	Rep rep;
	alias rep this;

	this(float r_, float g_, float b_) //!< Construct a color from floatingpoint values
	{
		this.r = r_;
		this.g = g_;
		this.b = b_;
	}

	@disable
	//"Don't know if this works correctly..."
	this(uint rgbColor) //!< Construct a color from R8G8B8 value like "0xffce08"
	{
		r = (rgbColor & 0xff) / 255.0f;
		g = ((rgbColor >> 8) & 0xff) / 255.0f;
		b = ((rgbColor >> 16) & 0xff) / 255.0f;
	}

	/// convert to RGB32, with channel shift specifications. The default values are for
	/// the blue channel occupying the least-significant byte
	uint toRGB32(int redShift = 16, int greenShift = 8, int blueShift = 0) const
	{
		uint ir = convertTo8bit(r);
		uint ig = convertTo8bit(g);
		uint ib = convertTo8bit(b);
		return (ib << blueShift) | (ig << greenShift) | (ir << redShift);
	}

	/// make black
	@disable
	void makeZero()
	{
		r = g = b = 0;
	}

	static Color black()
	{
		return Color(0f, 0.0f, 0f);
	}

	/// get the intensity of the color (direct)
	float intensity() const
	{
		return (r + g + b) / 3;
	}

	/// get the perceptual intensity of the color
	float intensityPerceptual() const
	{
		return cast(float)(r * 0.299 + g * 0.587 + b * 0.114);
	}

	/// Accumulates some color to the current
	void opOpAssign(string op)(const Color rhs) if (op == "+")
	{
		r += rhs.r;
		g += rhs.g;
		b += rhs.b;
	}

	void opOpAssign(string op)(float f)
		if (op == "*" || op == "/")
	{
		mixin("r " ~ op ~ "= f;");
		mixin("g " ~ op ~ "= f;");
		mixin("b " ~ op ~ "= f;");
	}
	
	ref inout(float) opIndex(int index) inout
	{
		return components[index];
	}

	Color opBinary(string op)(const Color rhs) const
		if (op == "+" || op == "-" || op == "*")
	{
		return mixin("Color(r" ~ op ~ "rhs.r, g" ~ op ~ "rhs.g, b" ~ op ~ "rhs.b)");
	}

	Color opBinary(string op)(float f) const
		if (op == "*" || op == "/")
	{
		return mixin("Color(r" ~ op ~ "f, g" ~ op ~ "f, b" ~ op ~ "f)");
	}

	T opCast(T)() const
		if (is(T == uint))
	{
		return this.toRGB32();
	}

	/// 0 = desaturate; 1 = don't change
	void adjustSaturation(float amount) 
	{
		float mid = intensity();
		r = r * amount + mid * (1 - amount);
		g = g * amount + mid * (1 - amount);
		b = b * amount + mid * (1 - amount);
	}

	/// Combines the results from the "left" and "right" camera for a single pixel.
	/// the implementation here creates an anaglyph image: it desaturates the input
	/// colors, masks them (left=red, right=cyan) and then merges them.
	static Color combineStereo(Color left, Color right)
	{
		left.adjustSaturation(0.25f);
		right.adjustSaturation(0.25f);
		return left * Color(1, 0, 0) + right * Color(0, 1, 1);
	}

	void toString(scope void delegate(const(char)[]) sink) const
	{
		import std.conv;
		sink("(");
		sink(to!string(r));
		sink(", ");
		sink(to!string(g));
		sink(", ");
		sink(to!string(b));
		sink(")");
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
	return (fabs(lhs.r - rhs.r) > THRESHOLD ||
	        fabs(lhs.g - rhs.g) > THRESHOLD ||
	        fabs(lhs.b - rhs.b) > THRESHOLD);
}

