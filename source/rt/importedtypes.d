module rt.importedtypes;

public import std.math;
public import gfm.math.funcs;

public import gfm.math.vector;
public import gfm.math.matrix;
import gfm.math.box;
import gfm.math.shapes;

alias Vector = gfm.math.vector.vec3d;
alias Matrix = gfm.math.matrix.mat3d;

struct Ray
{
	gfm.math.shapes.Ray!(double, 3) impl;
	int flags;
	int depth;

	alias impl this;
}

Vector mul(const Vector v, const Matrix m)
{
	return Vector(
		v.x * m.c[0][0] + v.y * m.c[1][0] + v.z * m.c[2][0],
		v.x * m.c[0][1] + v.y * m.c[1][1] + v.z * m.c[2][1],
		v.x * m.c[0][2] + v.y * m.c[1][2] + v.z * m.c[2][2]
	);
}

Matrix scaledIdentity(double x, double y, double z)
{
	auto result = Matrix.fromRows([Vector(0.0), Vector(0.0), Vector(0.0)]);
	result.c[0][0] = x;
	result.c[1][1] = y;
	result.c[2][2] = z;
	return result;
}

void clip(ref box2i box, int maxX, int maxY)
{
	box.max.x = min(box.max.x, maxX);
	box.max.y = min(box.max.y, maxY);
}