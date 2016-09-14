module rt.sceneloader;

import sdlang : SDLangEx = ParseException, parseSource, SDLValue = Value, SDLTag = Tag;
import std.json : JSONException, parseJSON, JSONValue, JSONType;
import std.file, std.path, std.string;
import std.typecons : Tuple, tuple;
import std.conv, std.traits, std.algorithm, std.range, std.exception, std.variant;

import rt.exception, rt.scene, rt.importedtypes, rt.color;
import util.factory2;
import core.meta : DerivedFrom, TypesToStrings;

/// Classes that support deserializing from scene
/// files should implement this interface.
interface Deserializable
{
    void deserialize(const SceneDscNode val, SceneLoadContext context);
}

/// Main entry point
Scene parseSceneFromFile(string filename)
{
    try
    {
        return filename
            .absolutePath()
            .readAndParseData()
            .loadFromAbstractDataFormat();
    }
    catch (FileException fEx)
    {
        throw new SceneNotFoundException(fEx.msg);
    }
    catch (JSONException jsonEx)
    {
        throw new InvalidSceneException("Invalid JSON in scene file!", jsonEx);
    }
    catch (SDLangEx sdlEx)
    {
        throw new InvalidSceneException("Invalid SDL in scene file!", sdlEx);
    }
}

private:

alias ParseInfo = Tuple!(const(SceneDscNode), "parsedValue", string, "filename");

ParseInfo readAndParseData(string filename)
{
    string ext = filename.extension.toLower;
    string data = filename.readText;

    switch (ext)
    {
        case ".json": return ParseInfo(parseJSON(data).makeVal(), filename);
        case ".sdl": return ParseInfo(parseSource(data).tags[0].makeVal(), filename);
        default:
            throw new InvalidSceneException(
                "Error loading scene: unknown file type!");
    }
}

Scene loadFromAbstractDataFormat(ParseInfo info)
{
    auto val = info.parsedValue;
    SceneLoadContext context = new SceneLoadContext(info.filename);
    context.scene = new Scene();

    with (context)
    with (scene)
    {
        setTo(val, name, "Name");
        setTo(val, settings, "GlobalSettings");
        setTo(val, camera, "Camera");
        setTo(val, environment, "Environment");
        setTo(val, lights, "Lights");
        setTo(val, geometries, "Geometries");
        setTo(val, textures, "Textures");
        setTo(val, shaders, "Shaders");
        setTo(val, nodes, "Nodes");
    }

    return context.scene;
}

public:

final class SceneLoadContext
{
    Scene scene;
    NamedEntities named() { return scene.namedEntities; }
    immutable string filePath;

    this(string filePath_ = null)
    {
        this.filePath = filePath_;
    }

    // Note: only one method is really needed.
    // The others are for convenience.
    bool set(T)(ref T property, const SceneDscNode val, string propertyName)
    {
        return setTo(val, property, propertyName);
    }

    T get(T)(const SceneDscNode val, string propertyName)
    {
        T result;
        setTo(val, result, propertyName);
        return result;
    }

    bool setTo(T)(const SceneDscNode val, ref T property, string propertyName)
    {
        // First - check if the property is specified in the sceme file:
        // Construct default if nothing specified.
        // Built-in types and struct are automatically initialized,
        // so we only need to instanciate classes.

        static if (is(T == class))
        {
            auto r = only(TypesToStrings!(DerivedFrom!T)).array
                .find!(str => val.isSpecified(str));

            if (r.empty)
            {
                property = new T();
                return false;
            }

            propertyName = r.front;
        }

        if (!val.isSpecified(propertyName))
            return false;

        // Next - get the corresponding value (built-in, array or object)
        auto subValue = val.getChild(propertyName);

        // Finally extract the value (recursively) and
        // assign it to the property
        property = extractValue!T(subValue);

        return true;
    }

    string resolveRelativePath(string path) const pure @safe
    {
        return absolutePath(path, this.filePath.dirName);
    }

private:

    T extractValue(T)(const SceneDscNode val)
    {
        static if (isBoolean!T || isIntegral!T || isFloatingPoint!T || isSomeString!T)
        {
            return val.get!T;
        }
        else static if (is(T : Deserializable))
        {
            return createObject!T(val);
        }
        else static if (is(T == Vector) || is(T == Color))
        {
            return T(val.getValues[0].get!double,
            val.getValues[1].get!double,
            val.getValues[2].get!double);
        }
        else static if (isArray!T)
        {
            alias Elem = ElementType!T;

            Elem[] result;

            static if (is(Elem : Deserializable))
                foreach (elem; val.getChildren)
                    result ~= createObject!(Elem)(elem);
            else
            {
                static if (isBoolean!Elem || isIntegral!Elem || isFloatingPoint!Elem || isSomeString!Elem)
                    foreach (elem; val.getValues)
                        result ~= elem.get!Elem;
                else
                    foreach (elem; val.getChildren)
                        result ~= extractValue!Elem(elem);
            }

            return result;
        }
        else
            static assert(0, "Unsupported type: " ~ T.stringof);
    }

    T createObject(T)(const SceneDscNode root)
    {
        string type = root.getType;

        T obj = makeInstanceOf!T(type);

        if (obj is null)
            throw new InvalidSceneException(
                "Unknown object type (or not yet supported): " ~ type);

        obj.deserialize(root, this);

        static if (NamedEntities.canBeStored!T)
            if (auto name = root.getName)
            {
                enforce!EntityWithDuplicateName(name !in scene.namedEntities.getArray!T(), name);
                scene.namedEntities.getArray!T()[name] = obj;
            }

        return obj;
    }
}

private SceneDscNode makeVal(const JSONValue json) { return new JsonValueWrapper(json); }

private SceneDscNode makeVal(const SDLTag sdl) { return new SdlValueWrapper(sdl); }

interface SceneDscNode
{
    final T get(T)() const @safe
    {
        static if (isBoolean!T) return getBool();
        else static if (isIntegral!T) return to!T(getInt());
        else static if (isFloatingPoint!T) return to!T(getFloat());
        else static if (isSomeString!T) return to!T(getString());
        else static assert(0, "Type not supported: " ~ T.stringof);
    }

    /// Note: Only available for top-level objects/tags
    string getType() const @trusted;

    string getName() const @trusted;

    bool isSpecified(string propertyName) const @trusted;

    SceneDscNode getChild(string propertyName) const @trusted;

    SceneDscNode[] getChildren() const @trusted;

    /// SDL specific, for JSON it will return the same content
    /// as the one returned from getChildren, but wrapped in sdlang.Value-s
    SDLValue[] getValues() const @trusted;

protected:
    bool getBool() const @trusted;
    long getInt() const @trusted;
    double getFloat() const @trusted;
    string getString() const @trusted;
}

class JsonValueWrapper : SceneDscNode
{
    this(const JSONValue v) { json = v; }

    override string getType() const @trusted
    {
        return json["type"].str;
    }

    override string getName() const @trusted
    {
        return isSpecified("name")? json["name"].str : null;
    }

    override bool isSpecified(string propertyName) const @trusted
    {
        return (propertyName in json.object) != null;
    }

    override SceneDscNode getChild( string propertyName) const @trusted
    {
        return new JsonValueWrapper(json[propertyName]);
    }

    override SceneDscNode[] getChildren() const @trusted
    {
        SceneDscNode[] result;

        foreach (subJson; json.array)
            result ~= new JsonValueWrapper(subJson);

        return result;
    }

    override SDLValue[] getValues() const @trusted
    {
        SDLValue[] result;

        foreach (subJson; json.array)
            result ~= SDLValue(number(subJson));

        return result;
    }

protected:
    override bool getBool() const @trusted
    {
        return boolean(json);
    }

    override long getInt() const @trusted
    {
        return to!long(number(json));
    }

    override double getFloat() const @trusted
    {
        return number(json);
    }

    override string getString() const @trusted
    {
        return json.str;
    }

private:
    JSONValue json;

    static double number(const JSONValue json) @trusted
    {
        switch (json.type)
        {
            case JSONType.float_: return json.floating;
            case JSONType.integer:
            case JSONType.uinteger: return json.integer;
            default: assert(0);
        }
    }

    static bool boolean(const JSONValue json) @trusted
    {
        switch (json.type)
        {
            case JSONType.true_: return true;
            case JSONType.false_: return false;
            default: assert(0);
        }
    }
}

class SdlValueWrapper : SceneDscNode
{
    this(const SDLTag v) { tag = v; }

    override string getType() const @trusted
    {
        return (cast(SDLTag)tag).name;
    }

    override string getName() const @trusted
    {
        if (tag.values.length && tag.values[0].convertsTo!string)
            return getString;

        else if (isSpecified("name"))
            return getChild("name").getString;

        else
            return null;
    }

    override bool isSpecified(string propertyName) const @trusted
    {
        return propertyName in (cast(SDLTag)tag).tags;
    }

    override SceneDscNode getChild(string propertyName) const @trusted
    {
        return new SdlValueWrapper((cast(SDLTag)tag).tags[propertyName][0]);
    }

    override SceneDscNode[] getChildren() const @trusted
    {
        SceneDscNode[] result;

        foreach(subTag; (cast(SDLTag)tag).tags)
            result ~= new SdlValueWrapper(subTag);

        return result;
    }

    override SDLValue[] getValues() const @trusted
    {
        SDLValue[] result;

        foreach(subTag; (cast(SDLTag)tag).values)
            result ~= subTag;

        return result;
    }

    SDLValue getValue(string name)
    {
        auto t = cast()tag;

        if (name in t.attributes)
            return t.attributes[name][0].value;
        else
            return SDLValue(null);
    }

protected:
    override bool getBool() const @trusted
    {
        return tag.values[0].get!(const bool);
    }

    override long getInt() const @trusted
    {
        return tag.values[0].get!(const long);
    }

    override double getFloat() const @trusted
    {
        return tag.values[0].get!(const double);
    }

    override string getString() const @trusted
    {
        return tag.values[0].get!(const string);
    }

private:
    const SDLTag tag;

    static void print(const SDLTag tag)
    {
        import std.stdio;
        writeln((cast(SDLTag)tag).name);

        foreach(t; (cast(SDLTag)tag).tags)
            print(t);
    }
}
