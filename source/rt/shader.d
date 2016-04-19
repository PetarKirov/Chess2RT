module rt.shader;

import std.typecons : Rebindable;
import gfm.math : clamp;
import rt.importedtypes, rt.ray, rt.color, rt.intersectable;
import rt.scene, rt.texture, rt.exception, rt.sceneloader;
import util.counter;
import util.random;
import util.prettyprint;

interface BRDF
{
    Color eval(const IntersectionData x, const Ray w_in, const Ray w_out) const @safe @nogc pure;

    void spawnRay(const IntersectionData x, const Ray w_in,
                  ref Ray w_out, ref Color colorEval, ref float pdf) const @safe @nogc;
}

interface IShader
{
    Color shade(const Ray ray, const IntersectionData data) const @safe @nogc pure;
}

abstract class Shader : IShader, BRDF, Deserializable
{
    Color color;

    @DontPrint Rebindable!(const Scene) scene;

    this()
    {

    }

    this(const Color color)
    {
        this.color = color;
    }

    void deserialize(const SceneDscNode val, SceneLoadContext context)
    {
        this.scene = context.scene;
        context.set(this.color, val, "color");
    }

    void toString(scope void delegate(const(char)[]) sink) const
    {
        import util.prettyprint;
        //printBaseMembers!(typeof(this), sink)(this);
    }
}

/// A Lambert (flat) shader
class Lambert : Shader
{
    /// A diffuse texture
    Rebindable!(const Texture) texture;

    this() { this(Color(1, 1, 1)); }

    this(const Color diffuseColor = Color(1, 1, 1), Texture texture = null)
    {
        super(diffuseColor);
        this.texture = texture;
    }

    Color shade(const Ray ray, const IntersectionData data) const @safe @nogc pure
    {
        // turn the normal vector towards us (if needed):
        Vector N = faceforward(ray.dir, data.normal);

        // fetch the material color. This is ether the solid color, or a color
        // from the texture, if it's set up.
        Color diffuseColor = texture ?
            this.texture.getTexColor(ray, data.u, data.v, N) :
            this.color;

        Color lightContrib = scene.settings.ambientLightColor;

        foreach(light; scene.lights)
        {
            auto avgColor = Color(0, 0, 0);
            foreach (j; 0 .. light.getNumSamples())
            {
                Vector lightPos;
                Color lightColor;
                light.getNthSample(j, data.p, lightPos, lightColor);
                if (lightColor.intensity() != 0 && scene.testVisibility(data.p + N * 1e-6, lightPos))
                {
                    Vector lightDir = lightPos - data.p;
                    lightDir.normalize();

                    // get the Lambertian cosine of the angle between the geometry's normal and
                    // the direction to the light. This will scale the lighting:
                    double cosTheta = dot(lightDir, N);
                    if (cosTheta > 0)
                    {
                        avgColor += lightColor / (data.p - lightPos).squaredLength() * cosTheta;
                    }
                }
            }
            lightContrib += avgColor / light.getNumSamples();
        }
        return diffuseColor * lightContrib;
    }

    Color eval(const IntersectionData x, const Ray w_in, const Ray w_out) const @safe @nogc pure
    {
        Vector N = faceforward(w_in.dir, x.normal);
        Color diffuseColor = this.color;

        if (texture)
            diffuseColor = texture.getTexColor(w_in, x.u, x.v, N);

        return diffuseColor * (1 / PI) * max(0.0, dot(w_out.dir, N));
    }

    void spawnRay(const IntersectionData x, const Ray w_in,
                  ref Ray w_out, ref Color colorEval, ref float pdf) const @safe @nogc
    {
        Vector N = faceforward(w_in.dir, x.normal);
        Color diffuseColor = this.color;

        if (texture)
            diffuseColor = texture.getTexColor(w_in, x.u, x.v, N);

        w_out = w_in;

        w_out.depth++;
        w_out.orig = x.p + N * 1e-6;
        w_out.dir = hemisphereSample(N);
        w_out.flags = w_out.flags | RayFlags.Diffuse;
        colorEval = diffuseColor * (1 / PI) * max(0.0, dot(w_out.dir, N));
        pdf = 1 / (2 * PI);
    }

    override void deserialize(const SceneDscNode val, SceneLoadContext context)
    {
        super.deserialize(val, context);
        string t;
        context.set(t, val, "texture");

        // Texture is optional
        this.texture = t in context.named.textures ?
        context.named.textures[t] :
        null;
    }

    override void toString(scope void delegate(const(char)[]) sink) const
    {
        import util.prettyprint;
        //printMembers!(typeof(this), sink)(this);
    }
}

Vector hemisphereSample(const Vector normal) @safe @nogc // not pure because of uniform(..)
{
    double u = uniform(0.0, 1.0);
    double v = uniform(0.0, 1.0);

    double theta = 2 * PI * u;
    double phi = acos(2 * v - 1) - PI/2;

    auto res = Vector(
        cos(theta) * cos(phi),
        sin(phi),
        sin(theta) * cos(phi)
    );

    if (dot(res, normal) < 0)
        res = -res;

    return res;
}

/// A Phong shader
class Phong : Shader
{
    Rebindable!(const Texture) texture;  // optional diffuse texture
    double exponent; // shininess of the material
    float strength; // strength of the cos^n specular component (0..1)

    this()
    {
        this(Color(1, 1, 1), 16.0);
    }

    this(const Color diffuseColor = Color(1, 1, 1), double exponent = 16.0, float strength = 1.0f, Texture texture = null)
    {
        super(diffuseColor);

        this.texture = texture;
        this.exponent = exponent,
        this.strength = strength;
    }

    Color shade(const Ray ray, const IntersectionData data) const @safe @nogc pure
    {
        // turn the normal vector towards us (if needed):
        Vector N = faceforward(ray.dir, data.normal);

        Color diffuseColor = this.color;
        if (texture) diffuseColor = texture.getTexColor(ray, data.u, data.v, N);

        Color lightContrib = scene.settings.ambientLightColor;
        auto specular = Color(0, 0, 0);

        foreach (light; scene.lights)
        {
            auto numSamples = light.getNumSamples();
            auto avgColor = Color(0, 0, 0);
            auto avgSpecular = Color(0, 0, 0);

            foreach (j; 0 .. numSamples)
            {
                Vector lightPos;
                Color lightColor;
                light.getNthSample(j, data.p, lightPos, lightColor);
                if (lightColor.intensity() != 0 && scene.testVisibility(data.p + N * 1e-6, lightPos))
                {
                    Vector lightDir = lightPos - data.p;
                    lightDir.normalize();

                    // get the Lambertian cosine of the angle between the geometry's normal and
                    // the direction to the light. This will scale the lighting:
                    double cosTheta = dot(lightDir, N);

                    // baseLight is the light that "arrives" to the intersection point
                    Color baseLight = lightColor / (data.p - lightPos).squaredLength();
                    if (cosTheta > 0)
                        avgColor += baseLight * cosTheta; // lambertian contribution

                    // R = vector after the ray from the light towards the intersection point
                    // is reflected at the intersection:
                    Vector R = reflect(-lightDir, N);

                    double cosGamma = dot(R, -ray.dir);
                    if (cosGamma > 0)
                        avgSpecular += baseLight * (cosGamma ^^ exponent) * strength; // specular contribution

                }
            }
            lightContrib += avgColor / numSamples;
            specular += avgSpecular / numSamples;
        }
        // specular is not multiplied by diffuseColor, since we want the specular hilights to be
        // independent on the material color. I.e., a blue ball has white hilights
        // (this is true for most materials, and false for some, e.g. gold)
        return diffuseColor * lightContrib + specular;
    }

    void spawnRay(const IntersectionData x, const Ray w_in,
                  ref Ray w_out, ref Color colorEval, ref float pdf) const @safe @nogc pure
    {
        assert(0);
    }

    Color eval(const IntersectionData x, const Ray w_in, const Ray w_out) const @safe @nogc pure
    {
        assert(0);
    }

    override void deserialize(const SceneDscNode val, SceneLoadContext context)
    {
        super.deserialize(val, context);

        context.set(this.exponent, val, "exponent");
        this.exponent = clamp(this.exponent, 1e-6, 1e6);

        context.set(this.strength, val, "strength");
        this.strength = clamp(this.strength, 0, 1e6);

        string t;
        context.set(t, val, "texture");

        // Texture is optional
        this.texture = t in context.named.textures ?
            context.named.textures[t] :
            null;
    }

    override void toString(scope void delegate(const(char)[]) sink) const
    {
        import util.prettyprint;
        //printMembers!(typeof(this), sink)(this);
    }
}
