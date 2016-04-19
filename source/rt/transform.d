module rt.transform;

import rt.importedtypes, rt.ray;

/// A transformation class, which implements model-view transform. Objects can be
/// arbitrarily scaled, rotated and translated.
struct Transform
{
    private
    {
        Matrix transform;
        Matrix inverseTransform;
        Matrix transposedInverse;
        Vector offset;
    }

    void toString(scope void delegate(const(char)[]) sink) const
    {
        sink(typeid(this).toString());
    }

    @safe @nogc pure:

    void reset()
    {
        transform = Matrix.identity;
        inverseTransform = transform.inverse();
        transposedInverse = inverseTransform.transposed();
        offset = Vector(0.0);
    }

    void scale(double x, double y, double z)
    {
        auto scaling = scaledIdentity(x, y, z);

        transform = transform * scaling;
        inverseTransform = transform.inverse();
        transposedInverse = inverseTransform.transposed();
    }

    void rotate(double yaw, double pitch, double roll)
    {
        transform = transform *
            Matrix.rotateX(radians(pitch)) *
            Matrix.rotateY(radians(yaw)) *
            Matrix.rotateZ(radians(roll));

        inverseTransform = transform.inverse();
        transposedInverse = inverseTransform.transposed();
    }

    void translate(const Vector V)
    {
        offset = V;
    }

    Vector point(Vector P) const
    {
        P = mul(P, transform);
        P = P + offset;

        return P;
    }

    Vector undoPoint(Vector P) const
    {
        P = P - offset;
        P = mul(P, inverseTransform);

        return P;
    }

    Vector direction(const Vector dir) const
    {
        return mul(dir, transform);
    }

    Vector normal(const Vector dir) const
    {
        return mul(dir, transposedInverse);
    }

    Vector undoDirection(const Vector dir) const
    {
        return mul(dir, inverseTransform);
    }

    Ray ray(const Ray inputRay) const
    {
        Ray result = inputRay;
        result.orig = point(inputRay.orig);
        result.dir   = direction(inputRay.dir);
        return result;
    }

    Ray undoRay(const Ray inputRay) const
    {
        Ray result = inputRay;
        result.orig = undoPoint(inputRay.orig);
        result.dir   = undoDirection(inputRay.dir);
        return result;
    }
}


