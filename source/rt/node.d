module rt.node;

import rt.geometry, rt.shader;

class Node
{
	Geometry geom;
	Shader shader;

	this(Geometry g, Shader s) { geom = g; shader = s; }
};