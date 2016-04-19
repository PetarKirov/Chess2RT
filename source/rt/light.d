module rt.light;

import rt.ray, rt.color;
import rt.intersectable, rt.sceneloader;

abstract class Light : Intersectable, Deserializable
{
    Color lightColor;
    float lightPower;

    Color color() const @safe @nogc pure
    {
        return lightColor * lightPower;
    }

    bool isInside(const Vector v) const @safe @nogc pure
    {
        return false;
    }

    float solidAngle(const Vector x) const @safe @nogc pure;

    /// get the number of samples this light requires
    size_t getNumSamples() const @safe @nogc pure;

    /**
     * Gets the n-th sample
     *
     * Params:
     *  sampleIdx = a sample index: 0 <= sampleIdx < getNumSamples().
     *  shadePos = the point we're shading. Can be used to modulate light power if the light doesn't shine eqeually in all directions.
     *  samplePos = [out] the generated light sample position
     *  color = [out] the generated light "color". This is usually has large components (i.e.,
     *                      it's base color * power
     */
    void getNthSample(size_t sampleIdx, const Vector shadePos,
                      ref Vector samplePos, ref Color color) const @safe @nogc pure;

    void deserialize(const SceneDscNode val, SceneLoadContext context)
    {
        context.set(this.lightColor, val, "color");
        context.set(this.lightPower, val, "power");
    }

    void toString(scope void delegate(const(char)[]) sink) const
    {
        import util.prettyprint;
        printBaseMembers!(typeof(this), sink)(this);
    }
}

class PointLight : Light
{
    Vector pos;

    override size_t getNumSamples() const pure
    {
        return 1;
    }

    override void getNthSample(size_t sampleIdx, const Vector shadePos, ref Vector samplePos, ref Color color) const @safe @nogc pure
    {
        samplePos = pos;
        color = this.color();
    }

    bool intersect(const Ray ray, ref IntersectionData data) const @safe @nogc pure
    {
        return false; // you can't intersect a point light
    }

    override float solidAngle(const Vector x) const @safe @nogc pure
    {
        return 0;
    }

    override void deserialize(const SceneDscNode val, SceneLoadContext context)
    {
        super.deserialize(val, context);

        context.set(this.pos, val, "pos");
    }

    override void toString(scope void delegate(const(char)[]) sink) const
    {
        import util.prettyprint;
        printMembers!(typeof(this), sink)(this);
    }
}
