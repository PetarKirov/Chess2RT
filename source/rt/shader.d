module rt.shader;

import rt.importedtypes;
import rt.color, rt.geometry;

abstract class Shader
{
public:
	this(const Color color)
	{
		this.color = color;
	}
	
	Color shade(Ray ray, const IntersectionData data);
	
protected:
	Color color;
};