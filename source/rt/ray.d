module rt.ray;

import gfm.math;

alias Vector = gfm.math.vector.vec3d;

struct Ray
{
	Vector start, dir;

	this(const Vector _start, const Vector _dir)
	{
		start = _start;
		dir = _dir;
	}
}

Vector reflect(const Vector ray, const Vector norm)
{
	Vector result = ray - 2 * dot(ray, norm) * norm;
	result.normalize();
	return result;
}

Vector faceforward(const Vector ray, const Vector norm)
{
	if (dot(ray, norm) < 0) return norm;
	else return -norm;
}

Vector project(const Vector v, int a, int b, int c)
{
	Vector result;
	result[a] = v[0];
	result[b] = v[1];
	result[c] = v[2];
	return result;
}


Vector unproject(const Vector v, int a, int b, int c)
{
	Vector result;
	result[0] = v[a];
	result[1] = v[b];
	result[2] = v[c];
	return result;
}

Ray project(const Ray v, int a, int b, int c)
{
	return Ray(project(v.start, a, b, c), project(v.dir, a, b, c));
}