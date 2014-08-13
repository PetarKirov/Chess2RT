module rt.light;

import rt.importedtypes;
import rt.color;

class Light
{
public:
	Vector lightPos;
	Color lightColor;
	float lightPower;

	this(const Vector position, Color color, float power)
	{
		this.lightPos = position;
		this.lightColor = color;
		this.lightPower = power;
	}
}