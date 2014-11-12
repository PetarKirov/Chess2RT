module rt.sceneloader;

import sdlang, std.json;
import std.file, std.path, std.string;
import std.conv, std.traits, std.range, std.exception, std.variant;

import rt.exception, rt.scene, rt.importedtypes, rt.color;
import util.factory2;

/// Classes that support deserializing from scene
/// files should implement this interface.
interface Deserializable
{
	void deserialize(const Value val, SceneLoadContext context);
}

/// Main entry point
Scene parseSceneFromFile(string fileName)
{
	try
	{
		return fileName
			.readAndParseData()
			.loadFromAbstractDataFormat;
	}
	catch (FileException fEx)
	{
		throw new SceneNotFoundException();
	}
	catch (JSONException jsonEx)
	{
		throw new InvalidSceneException("Invalid JSON in scene file!", jsonEx);
	}
	catch (SDLangParseException sdlEx)
	{
		throw new InvalidSceneException("Invalid SDL in scene file!", sdlEx);
	}
}

private: 

const(Value) readAndParseData(string fileName)
{
	string ext = fileName.extension.toLower;
	string data = fileName.readText;
	
	switch (ext)
	{
		case ".json": return parseJSON(data).makeVal();
		case ".sdl": return parseSource(data).tags[0].makeVal();
		default:
			throw new InvalidSceneException(
				"Error loading scene: unknown file type!");
	}
}

Scene loadFromAbstractDataFormat(const Value val)
{
	SceneLoadContext context = new SceneLoadContext();	
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
	
	// Note: only one method is really needed.
	// The others are for convenience.
	bool set(T)(ref T property, const Value val, string propertyName)
	{
		return setTo(val, property, propertyName);
	}
	
	T get(T)(const Value val, string propertyName)
	{
		T result;
		setTo(val, result, propertyName);
		return result;
	}

	bool setTo(T)(const Value val, ref T property, string propertyName)
	{		
		// First - check if the property is specified in the sceme file:
		// Construct default if nothing specified.
		// Built-in types and struct are automatically initialized,
		// so we only need to instanciate classes.
		if (!val.isSpecified(propertyName))
		{	
			static if (is(T == class))
				property = new T();
			return false;
		}
		
		// Next - get the corresponding value (built-in, array or object)
		auto subValue = val.getChild(propertyName);
		
		// Finally extract the value (recursively) and
		// assign it to the property
		property = extractValue!T(subValue);

		return true;
	}

private:

	T extractValue(T)(const Value val)
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
	
	T createObject(T)(const Value v)
	{
		string type = v.getType;

		T obj = makeInstanceOf!T(type);

		if (obj is null)
			throw new InvalidSceneException(
				"Unknown object type (or not yet supported): " ~ type);

		obj.deserialize(v, this);
		
		static if (NamedEntities.canBeStored!T)
			if (v.isSpecified("name"))
			{
				string name = v.getChild("name").getString;
				enforce(name !in scene.namedEntities.getArray!T(),
				        new EntityWithDuplicateName(name));
				scene.namedEntities.getArray!T()[name] = obj;
			}
		
		return obj;
	}
}

private Value makeVal(const JSONValue json) { return new JsonValueWrapper(json); }

private Value makeVal(const Tag sdl) { return new SdlValueWrapper(sdl); }

interface Value
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

	bool isSpecified(string propertyName) const @trusted;

	Value getChild(string propertyName) const @trusted;

	Value[] getChildren() const @trusted;

	/// SDL specific, for JSON it will return the same content
	/// as the one returned from getChildren, but wrapped in sdlang.Value-s
	sdlang.Value[] getValues() const @trusted;

protected:
	bool getBool() const @trusted;
	long getInt() const @trusted;
	double getFloat() const @trusted;
	string getString() const @trusted;
}

class JsonValueWrapper : Value
{
	this(const JSONValue v) { json = v; }

	override string getType() const @trusted 
	{
		return json["type"].str;
	}

	override bool isSpecified(string propertyName) const @trusted
	{
		return (propertyName in json.object) != null;
	}

	override Value getChild( string propertyName) const @trusted
	{
		return new JsonValueWrapper(json[propertyName]);
	}

	override Value[] getChildren() const @trusted
	{
		Value[] result;

		foreach (subJson; json.array)
			result ~= new JsonValueWrapper(subJson);

		return result;
	}

	override sdlang.Value[] getValues() const @trusted
	{
		sdlang.Value[] result;
		
		foreach (subJson; json.array)
			result ~= sdlang.Value(number(subJson));
		
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
			case JSON_TYPE.FLOAT: return json.floating;
			case JSON_TYPE.INTEGER:
			case JSON_TYPE.UINTEGER: return json.integer;
			default: assert(0);
		}
	}

	static bool boolean(const JSONValue json) @trusted
	{
		switch (json.type)
		{
			case JSON_TYPE.TRUE: return false;
			case JSON_TYPE.FALSE: return true;
			default: assert(0);
		}
	}
}

class SdlValueWrapper : Value
{
	this(const Tag v) { tag = v; }

	override string getType() const @trusted
	{
		return (cast(Tag)tag).name;
	}
	
	override bool isSpecified(string propertyName) const @trusted
	{
		return propertyName in (cast(Tag)tag).tags;
	}
	
	override Value getChild( string propertyName) const @trusted
	{
		return new SdlValueWrapper((cast(Tag)tag).tags[propertyName][0]);
	}
	
	override Value[] getChildren() const @trusted
	{
		Value[] result;

		foreach(subTag; (cast(Tag)tag).tags)
			result ~= new SdlValueWrapper(subTag);

		return result;
	}

	override sdlang.Value[] getValues() const @trusted
	{
		sdlang.Value[] result;
		
		foreach(subTag; (cast(Tag)tag).values)
			result ~= subTag;
		
		return result;
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
	const Tag tag;

	static void print(const Tag tag)
	{
		import std.stdio;
		writeln((cast(Tag)tag).name);
		
		foreach(t; (cast(Tag)tag).tags)
			print(t);
	}
}
