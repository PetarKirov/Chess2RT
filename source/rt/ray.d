module rt.ray;

import rt.importedtypes;

// flags that mark a ray in some way, so the behaviour of the raytracer can be altered.
enum RayFlags
{
	// RF_DEBUG - the ray is a debug one (launched from a mouse-click on the rendered image).
	// raytrace() prints diagnostics when it encounters such a ray.
	RF_DEBUG    = 0x0001,
	
	// RF_SHADOW - the ray is a shadow ray. This hints the raytracer to skip some calculations
	// (since the IntersectionData won't be used for shading), and to disable backface culling
	// for Mesh objects.
	RF_SHADOW   = 0x0002,
	
	// RF_GLOSSY - the ray has hit some glossy surface somewhere along the way.
	// so if it meets a new glossy surface, it can safely use lower sampling settings.
	RF_GLOSSY   = 0x0004,
	
	// last constituent of a ray path was a diffuse surface
	RF_DIFFUSE  = 0x0008,
};

//struct Ray
//{
//	Vector start, dir;
//
//	this(const Vector _start, const Vector _dir)
//	{
//		start = _start;
//		dir = _dir;
//	}
//}

Vector reflect(const Vector ray, const Vector norm) @nogc
{
	Vector result = ray - 2 * dot(ray, norm) * norm;
	result.normalize();
	return result;
}

Vector faceforward(const Vector ray, const Vector norm) @nogc
{
	if (dot(ray, norm) < 0) return norm;
	else return -norm;
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