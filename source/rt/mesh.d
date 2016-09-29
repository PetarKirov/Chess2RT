///
module core.mesh;

import rt.geometry, rt.sceneloader;
import rt.importedtypes, rt.ray, rt.intersectable;

import core.bbox;

import std.stdio : writeln;

/// A structure to represent a single triangle in the mesh
struct Triangle {
    int[3] v; //!< holds indices to the three vertices of the triangle (indexes in the `vertices' array in the Mesh)
    int[3] n; //!< holds indices to the three normals of the triangle (indexes in the `normals' array)
    int[3] t; //!< holds indices to the three texture coordinates of the triangle (indexes in the `uvs' array)
    Vector gnormal; //!< The geometric normal of the mesh (AB ^ AC, normalized)
    Vector dNdx, dNdy;
    Vector AB, AC; //!< precomputed vectors B - A and C - A
    Vector ABcrossAC; //!< precomputed vector AB ^ AC

    this(in char[] a, in char[] b, in char[] c)
    {
        foreach (i, vertex; [a, b, c])
        {
            import std.algorithm, std.conv, std.array;
            auto ids = vertex.splitter('/').array;

            assert (ids.length > 0);
            v[i] = ids[0].to!uint;
            t[i] = ids.length > 1? ids[1].to!uint : 0;
            n[i] = ids.length > 2? ids[2].to!uint : 0;
        }
    }

    string toString() const
    {
        import std.format;
        return format("Triangle(%s %s %s)", v, n, t);
    }
}



class Mesh : Geometry
{
    Vector[] vertices;
    Vector[] normals;
    Vector[] uvs;
    Triangle[] triangles;
    BBox bbox;

    bool faceted;
    bool backfaceCulling;

	import core.kd_tree;

	KDTreeNode* kdroot;

    pure @nogc @safe nothrow
    static void solve2D(Vector A, Vector B, Vector C, ref double x, ref double y)
    {
        // solve: x * A + y * B = C
        double[2][2] mat = [ [ A.x, B.x ], [ A.y, B.y ] ];
        double[2] h = [ C.x, C.y ];

        double Dcr = mat[0][0] * mat[1][1] - mat[1][0] * mat[0][1];
        x =         (     h[0] * mat[1][1] -      h[1] * mat[0][1]) / Dcr;
        y =         (mat[0][0] *      h[1] - mat[1][0] *      h[0]) / Dcr;
    }

    void loadFromWavefrontObj(in char[] file)
    {
        import std.algorithm, std.range, std.array : array;
        import std.conv : to;
        import std.string : strip;

        Mesh m = this;

        m.vertices ~= Vector(0, 0, 0);
        m.normals ~= Vector(0, 0, 0);
        m.uvs ~= Vector(0, 0, 0);

        // load data
        file.splitter('\n')
            .map!strip
            .filter!(l => l.length && l[0] != '#')
            .map!(l => l.splitter(' ').filter!(token => !token.empty).array)
            .each!((line)
                {
                    switch (line.front)
                    {
                        case  "v":  m.vertices ~= Vector(line[1].to!float, line[2].to!float, line[3].to!float); break;
                        case "vn":   m.normals ~= Vector(line[1].to!float, line[2].to!float, line[3].to!float); break;
                        case "vt":       m.uvs ~= Vector(line[1].to!float, line[2].to!float, 0); break;
                        case  "f": m.triangles ~= Triangle(line[1], line[2], line[3]); break;
                        default: break;
                    }
                });

        // post process
        foreach (ref T; m.triangles)
        {
            Vector A = vertices[T.v[0]];
            Vector B = vertices[T.v[1]];
            Vector C = vertices[T.v[2]];
            Vector AB = B - A;
            Vector AC = C - A;
            T.AB = AB;
            T.AC = AC;

            // compute the geometric normal of this triangle:
            T.gnormal = T.ABcrossAC = AB.cross(AC);
            T.gnormal.normalize();


            // compute the dNd(x|y) vectors of this triangle:
            Vector texA = uvs[T.t[0]];
            Vector texB = uvs[T.t[1]];
            Vector texC = uvs[T.t[2]];

            Vector texAB = texB - texA;
            Vector texAC = texC - texA;

            double px, py, qx, qy;
            solve2D(texAB, texAC, Vector(1, 0, 0), px, qx); // (1)
            solve2D(texAB, texAC, Vector(0, 1, 0), py, qy); // (2)

            T.dNdx = AB * px + AC * qx;
            T.dNdy = AB * py + AC * qy;
            T.dNdx.normalize();
            T.dNdy.normalize();
        }

        /*
		if (hasNormals && !autoSmooth)
			return;

		hasNormals = true;
		normals.resize(vertices.length, Vector(0, 0, 0)); // extend the normals[] array, and fill with zeros
		foreach (int i; 0 .. triangles.length)
			foreach (int j; 0 .. 3)
			{
				triangles[i].n[j] = triangles[i].v[j];
				normals[triangles[i].n[j]] += triangles[i].gnormal;
			}

		foreach (int i; 1 .. normals.length)
			if (normals[i].lengthSqr() > 1e-9) normals[i].normalize();*/
    }

    pure @nogc @safe nothrow
    bool intersect(const(Ray) _ray, ref IntersectionData info) const
    {
		import std.algorithm.searching : any;
		RRay ray = RRay(_ray);
		ray.prepareForTracing();

		if (!bbox.testIntersect(ray))
			return false;

		info.dist = double.infinity;

		if (kdroot)
			return intersectKD(kdroot, bbox, ray, info);
		else
			return triangles[].any!((in ref Triangle t) => intersectTriangle(ray, t, info));
    }

    pure @nogc @safe nothrow
    bool intersectKD(const(KDTreeNode)* node, in ref BBox bbox, in ref RRay ray, ref IntersectionData info) const
    {
        return false;
    }

    pure @nogc @safe nothrow
    bool intersectTriangle(const ref RRay ray, const ref Triangle t, ref IntersectionData info) const
    {
		import std.math : fabs;
        if (backfaceCulling && dot(ray.dir, t.gnormal) > 0) return false;
        Vector A = vertices[t.v[0]];

        Vector H = ray.orig - A;
        Vector D = ray.dir;

        double Dcr = - dot(t.ABcrossAC, D);

        if (fabs(Dcr) < 1e-12) return false;

        double rDcr = 1 / Dcr;
        double gamma = dot(t.ABcrossAC, H) * rDcr;
        if (gamma < 0 || gamma > info.dist) return false;

        Vector HcrossD = cross(H, D);
        double lambda2 = dot(HcrossD, t.AC) * rDcr;
        if (lambda2 < 0 || lambda2 > 1) return false;

        double lambda3 = -dot(t.AB, HcrossD) * rDcr;
        if (lambda3 < 0 || lambda3 > 1) return false;

        if (lambda2 + lambda3 > 1) return false;

        info.dist = gamma;
        info.ip = ray.orig + ray.dir * gamma;
        if (!faceted) {
            Vector nA = normals[t.n[0]];
            Vector nB = normals[t.n[1]];
            Vector nC = normals[t.n[2]];

            info.normal = nA + (nB - nA) * lambda2 + (nC - nA) * lambda3;
            info.normal.normalize();
        } else {
            info.normal = t.gnormal;
        }

        info.dNdx = t.dNdx;
        info.dNdy = t.dNdy;

        Vector uvA = uvs[t.t[0]];
        Vector uvB = uvs[t.t[1]];
        Vector uvC = uvs[t.t[2]];

        Vector uv = uvA + (uvB - uvA) * lambda2 + (uvC - uvA) * lambda3;
        info.u = uv.x;
        info.v = uv.y;
        info.g = this;

        return true;
    }

    bool isInside(const Vector p) const pure @nogc @safe
    {
        return false;
    }

    void deserialize(const SceneDscNode val, SceneLoadContext context)
    {
        string file = context.resolveRelativePath(
            context.get!string(val, "file"));

        import std.file : read;
        loadFromWavefrontObj(cast(char[])file.read);

    }
}

unittest
{
    import std.file : read;

    auto data = cast(char[])"./data/geom/heart.obj".read();

    auto m = Mesh!Triangle.loadFromWavefrontObj(cast(char[])data);

    writeln(m.vertices.length, "\n", m.vertices);
    writeln(m.uvs.length, "\n", m.uvs);
    writeln(m.triangles.length, "\n", m.triangles);
}
