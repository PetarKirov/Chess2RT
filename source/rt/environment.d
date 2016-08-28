module rt.environment;

import rt.importedtypes, rt.color, rt.sceneloader;

class Environment : Deserializable
{
    Color getEnvironment(const Vector dir) const @safe @nogc pure
    {
        return Color(0, 0, 0);
    }

    void deserialize(const SceneDscNode val, SceneLoadContext context)
    {
    }
}

class CubemapEnvironment
{
    private void loadFromFolder(string path)
    {
        import std.algorithm.setops :  cartesianProduct;
        import std.range : only;
        import std.algorithm.iteration : map, joiner;
        import std.array : array;

        string[1] paths = [path];
        enum prefixes = ["neg", "pos"];
        enum axes = ["x", "y", "z"];
        enum suffixes = [".bmp", ".exr"];

        auto allFilePaths =
            cartesianProduct(paths[], prefixes, axes, suffixes)
            .map!(tuple => only(tuple.expand).joiner("/"));

        import std.stdio;
        writefln("%(%s\n%)", allFilePaths);
    }
}

unittest
{
    auto c = new CubemapEnvironment();
    c.loadFromFolder("__fold__");
}

