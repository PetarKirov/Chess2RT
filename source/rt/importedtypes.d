module rt.importedtypes;

public import std.math;
public import gfm.math.funcs;

public import gfm.math.vector;
public import gfm.math.matrix;
import gfm.math.box;

alias Vector = gfm.math.vector.vec3d;
alias Matrix = gfm.math.matrix.mat3d;

struct Ray
{
	Vector orig;
	Vector dir;

	int flags;
	int depth;
}

Vector mul(const Vector v, const Matrix m) @nogc
{
	return Vector(
		v.x * m.c[0][0] + v.y * m.c[1][0] + v.z * m.c[2][0],
		v.x * m.c[0][1] + v.y * m.c[1][1] + v.z * m.c[2][1],
		v.x * m.c[0][2] + v.y * m.c[1][2] + v.z * m.c[2][2]
	);
}

Matrix scaledIdentity(double x, double y, double z) @nogc
{
	auto result = Matrix(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
	result.c[0][0] = x;
	result.c[1][1] = y;
	result.c[2][2] = z;
	return result;
}

void clip(ref box2i box, int maxX, int maxY) @nogc
{
	box.max.x = min(box.max.x, maxX);
	box.max.y = min(box.max.y, maxY);
}

Vector project(const Vector v, int a, int b, int c) @nogc
{
	Vector result;
	result[a] = v[0];
	result[b] = v[1];
	result[c] = v[2];
	return result;
}

Vector unproject(const Vector v, int a, int b, int c) @nogc
{
	Vector result;
	result[0] = v[a];
	result[1] = v[b];
	result[2] = v[c];
	return result;
}

Ray project(Ray v, int a, int b, int c) @nogc
{
	v.orig = project(v.orig, a, b, c);
	v.dir = project(v.dir, a, b, c);
	return v;
}