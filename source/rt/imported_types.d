module rt.importedtypes;

public import std.algorithm : min, max, clamp;
public import std.math : PI, fabs, sqrt, sin, cos, tan, asin, acos, atan2, floor;
public import gfm.math.funcs : radians;
public import gfm.math.vector;
public import gfm.math.matrix;
import gfm.math.box;

alias Vector = gfm.math.vector.vec3d;
alias Matrix = gfm.math.matrix.mat3d;

Vector mul(const Vector v, const Matrix m) pure nothrow @safe @nogc
{
    return Vector(
        v.x * m.c[0][0] + v.y * m.c[1][0] + v.z * m.c[2][0],
        v.x * m.c[0][1] + v.y * m.c[1][1] + v.z * m.c[2][1],
        v.x * m.c[0][2] + v.y * m.c[1][2] + v.z * m.c[2][2]
    );
}

Matrix scaledIdentity(double x, double y, double z) pure nothrow @safe @nogc
{
    auto result = Matrix(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
    result.c[0][0] = x;
    result.c[1][1] = y;
    result.c[2][2] = z;
    return result;
}

void clip(ref box2i box, int maxX, int maxY) pure nothrow @safe @nogc
{
    box.max.x = min(box.max.x, maxX);
    box.max.y = min(box.max.y, maxY);
}

public import std.math : isFinite;

bool isFiniteVec(in ref Vector v) pure nothrow @safe @nogc
{
    return v[0].isFinite && v[1].isFinite && v[2].isFinite;
}

int maxDimension(in ref Vector v) pure nothrow @safe @nogc
{
    int maxDim = 0;

    with (v)
    {
        double maxVal = fabs(x);
        if (fabs(y) > maxVal)
        {
            maxDim = 1;
            maxVal = fabs(y);
        }
        if (fabs(z) > maxVal)
            maxDim = 2;
    }

    return maxDim;
}

Vector project(const Vector v, int a, int b, int c) pure nothrow @safe @nogc
{
    Vector result;
    result[a] = v[0];
    result[b] = v[1];
    result[c] = v[2];
    return result;
}

Vector unproject(const Vector v, int a, int b, int c) pure nothrow @safe @nogc
{
    Vector result;
    result[0] = v[a];
    result[1] = v[b];
    result[2] = v[c];
    return result;
}

Vector reflect(const Vector ray, const Vector norm) pure nothrow @safe @nogc
{
    Vector result = ray - 2 * dot(ray, norm) * norm;
    result.normalize();
    return result;
}

Vector faceforward(const Vector ray, const Vector norm) pure nothrow @safe @nogc
{
    if (dot(ray, norm) < 0) return norm;
    else return -norm;
}
