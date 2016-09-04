module rt.node;

import rt.importedtypes, rt.ray, rt.transform, rt.intersectable, rt.geometry, rt.shader, rt.texture, rt.sceneloader;

class Node : Intersectable, Deserializable
{
    Geometry geom;
    Shader shader;
    Texture bumpmap;
    Transform transform;

    this()
    {
        transform.reset();
    }

    bool isInside(const Vector p) const
    {
        return geom.isInside(transform.undoPoint(p));
    }

    // intersect a ray with a node, considering the Model transform attached to the node.
    bool intersect(const Ray ray, ref IntersectionData data) const @nogc @safe pure
    {
        // world space -> object's canonic space
        Ray rayCanonic;
        rayCanonic.orig = transform.undoPoint(ray.orig);
        rayCanonic.dir = transform.undoDirection(ray.dir);
        rayCanonic.flags = ray.flags;
        rayCanonic.depth = ray.depth;

        // save the old "best dist", in case we need to restore it later
        double oldDist = data.dist;                      // (1)
        double rayDirLength = rayCanonic.dir.magnitude();
        data.dist *= rayDirLength;                       // (2)
        rayCanonic.dir.normalize();                      // (3)
        if (!geom.intersect(rayCanonic, data))
        {
            data.dist = oldDist;                         // (4)
            return false;
        }

        // The intersection found is in object space, convert to world space:
        data.normal = transform.normal(data.normal).normalized();
        data.dNdx = transform.direction(data.dNdx).normalized();
        data.dNdy = transform.direction(data.dNdy).normalized();
        data.p = transform.point(data.p);
        data.dist /= rayDirLength;                        // (5)
        return true;

        /*
        * ^^^
        * Explanation for the numbered lines.
        *
        * Since the geometries in the scene may use different transforms, the only universal
        * coordinate system are the world coords. The applies to distances, too. We use data.dist
        * for culling geometries that won't improve the closest dist we've found so far in raytrace().
        * So, if a transform contains scaling, we need to adjust data.dist so that it's still valid
        * in the object's canonic space. Since ray.dir undergoes scaling as well, we use its length
        * to multiply the data.dist in (2). This essentially transforms the distance from world space
        * to object's canonic space. We save the old value of the distance in (1), in case there isn't
        * an intersection (4). Of course, Geometry::intersect assumes that ray.dir is an unit vector,
        * and we cater for that in (3). Finally, when the results arrive, convert the data.dist back
        * from object to world space (5).
        *
        * This implements the "bonus" from HW5/medium/group1.
        */
    }

    void deserialize(const SceneDscNode val, SceneLoadContext context)
    {
        string geom, shad, bump;
        context.set(geom, val, "geometry");
        context.set(shad, val, "shader");
        context.set(bump, val, "bump");

        this.geom = context.named.geometries[geom];
        this.shader = context.named.shaders[shad];
        // bumpmap is optional
        this.bumpmap = bump in context.named.textures ?
            context.named.textures[bump] :
            null;

        Vector v;

        if (context.set(v, val, "scale"))
            this.transform.scale(v.x, v.y, v.z);

        if (context.set(v, val, "rotate"))
            this.transform.scale(v.x, v.y, v.z);

        if (context.set(v, val, "translate"))
            this.transform.translate(v);
    }

    void toString(scope void delegate(const(char)[]) sink) const
    {
        import util.prettyprint;
        printMembers!(typeof(this), sink)(this);
    }
}

