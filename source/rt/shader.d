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
    Color color = Color(0, 0, 0);

    @DontPrint Rebindable!(const Scene) scene;

    this()
    {

    }

    this(const Color color)
    {
        this.color = color;
    }

    Color eval(const IntersectionData x, const Ray w_in, const Ray w_out) const @safe @nogc pure
    {
        return Color(1f, 0f, 0f);
    }

    void spawnRay(const IntersectionData x, const Ray w_in,
        ref Ray w_out, ref Color colorEval, ref float pdf) const @safe @nogc
    {
        w_out.dir = Vector(1, 0, 0);
        colorEval = Color(1, 0, 0);
        pdf = -1;
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

    this() { }

    Color shade(const Ray ray, const IntersectionData data) const @safe @nogc pure
    {
        // turn the normal vector towards us (if needed):
        Vector N = faceforward(ray.dir, data.normal);

        // fetch the material color. This is ether the solid color, or a color
        // from the texture, if it's set up.
        Color diffuseColor = texture ?
            this.texture.getTexColor(data) :
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
                        avgColor += lightColor / (data.p - lightPos).squaredMagnitude() * cosTheta;
                    }
                }
            }
            lightContrib += avgColor / light.getNumSamples();
        }
        return diffuseColor * lightContrib;
    }

    override Color eval(const IntersectionData x, const Ray w_in, const Ray w_out) const @safe @nogc pure
    {
        Color diffuse = texture ? texture.getTexColor(x) : color;

        Vector N = faceforward(w_in.dir, x.normal);

        //      color      BRDF        Kajiya's cosine term
        return diffuse * (1 / PI) * max(0.0, dot(w_out.dir, N));
    }

    override void spawnRay(const IntersectionData x, const Ray w_in,
                  ref Ray w_out, ref Color colorEval, ref float pdf) const @safe @nogc
    {
        Vector N = faceforward(w_in.dir, x.normal);
        Color diffuseColor = this.color;

        if (texture)
            diffuseColor = texture.getTexColor(x);

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
        if (texture) diffuseColor = texture.getTexColor(data);

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
                    Color baseLight = lightColor / (data.p - lightPos).squaredMagnitude();
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

    override void spawnRay(const IntersectionData x, const Ray w_in,
                  ref Ray w_out, ref Color colorEval, ref float pdf) const @safe @nogc pure
    {
        assert(0);
    }

    override Color eval(const IntersectionData x, const Ray w_in, const Ray w_out) const @safe @nogc pure
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

class Refraction : Shader
{
	double ior = 1.33;
	double multiplier = 0.99;

    this() {}

    static Vector refract(in Vector i, in Vector n, double ior) pure nothrow @nogc @safe
    {
        double NdotI = i.dot(n);
        double k = 1 - (ior * ior) * (1 - NdotI * NdotI);
        if (k < 0.0)        // Check for total inner reflection
            return Vector(0, 0, 0);
        return ior * i - (ior * NdotI + sqrt(k)) * n;
    }

    Color shade(const Ray ray, const IntersectionData info) const @safe @nogc pure
	{
        Vector refr;
        if (dot(ray.dir, info.normal) < 0) {
            // entering the geometry
            refr = refract(ray.dir, info.normal, 1 / ior);
        } else {
            // leaving the geometry
            refr = refract(ray.dir, -info.normal, ior);
        }
        if (refr.squaredMagnitude() == 0) return Color(0, 0, 0);
        Ray newRay = ray;
        newRay.orig = info.ip - faceforward(ray.dir, info.normal) * 0.000001;
        newRay.dir = refr;
        newRay.depth++;
        import rt.renderer : raytrace;
        return raytrace(scene, newRay) * multiplier;
	}

    override void deserialize(const SceneDscNode val, SceneLoadContext context)
	{
        this.scene = context.scene;
        context.set(multiplier, val, "multiplier");
        context.set(ior, val, "ior");
        ior = clamp(ior, 1e-6, 10);
	}
}

class Reflection : Shader
{
    double multiplier = 0.99;
	double glossiness = 1;
    int numSamples = 32;

    this() {}

    override void deserialize(const SceneDscNode val, SceneLoadContext context)
	{
        this.scene = context.scene;
        context.set(multiplier, val, "multiplier");
        context.set(glossiness, val, "glossiness");
        glossiness = clamp(glossiness, 0, 1);
        context.set(numSamples, val, "numSamples");
	}

    Color shade(const Ray ray, const IntersectionData info) const @safe @nogc pure
    {
        import rt.renderer;
        Vector n = faceforward(ray.dir, info.normal);

        if (glossiness == 1)
        {
            Ray newRay = ray;
            newRay.orig = info.ip + n * 0.000001;
            newRay.dir = reflect(ray.dir, n);
            newRay.depth++;

            return  raytrace(scene, newRay) * multiplier;
        }
        /*
        else
        {
            Random rnd = getRandomGen();
            Color result;
            int count = numSamples;
            if (ray.depth > 0)
            count = 2;
            for (int i = 0; i < count; i++)
            {
                Vector a, b;
                orthonormalSystem(n, a, b);
                double x, y, scaling;

                rnd.unitDiscSample(x, y);
                //
                scaling = tan((1 - glossiness) * PI/2);
                x *= scaling;
                y *= scaling;

                Vector modifiedNormal = n + a * x + b * y;

                Ray newRay = ray;
                newRay.start = info.ip + n * 0.000001;
                newRay.dir = reflect(ray.dir, modifiedNormal);
                newRay.depth++;

                result += raytrace(newRay) * multiplier;
            }
            return result / count;
        }*/
        assert (0);
    }
}

class Layered : Shader
{
    Layer[32] layers;
    uint numLayers;

    this() {}

	struct Layer
	{
		Shader shader;
		Color blend = Color(0, 0, 0);
		Texture texture;
	}

    Color shade(const Ray ray, const IntersectionData data) const @safe @nogc pure
	{
        Color result;
        foreach (i; 0 .. numLayers)
        {
            const Color fromLayer = layers[i].shader.shade(ray, data);

            const Color blendAmount = layers[i].texture?
                layers[i].blend * layers[i].texture.getTexColor(data):
                layers[i].blend;

            result = blendAmount * fromLayer + (Color(1, 1, 1) - blendAmount) * result;
        }
        return result;
	}

    override void deserialize(const SceneDscNode val, SceneLoadContext context)
	{
        assert (val.getChildren.length <= layers.length);
        foreach(idx, child; val.getChildren)
        {
            const colorValues = child.getValues;

            auto c = Color(
                colorValues[0].get!float,
                colorValues[1].get!float,
                colorValues[2].get!float
            );

            auto ch = cast(SdlValueWrapper)child;

            auto pShader = ch.getValue("shader").peek!string;
            auto pTexture = ch.getValue("texture").peek!string;

            Shader s = pShader? context.named.shaders[*pShader]: null;
            Texture t = pTexture? context.named.textures[*pTexture] : null;

            this.layers[numLayers++] = Layer(s, c, t);
        }
	}
}

