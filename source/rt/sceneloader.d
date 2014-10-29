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
	void deserialize(Value val, SceneLoadContext context);
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

Value readAndParseData(string fileName)
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

Scene loadFromAbstractDataFormat(Value val)
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

class SceneLoadContext
{
	Scene scene;	
	NamedEntities named() { return scene.namedEntities; }
	
	// Note: only one method is really needed.
	// The others are for convenience.
	void set(T)(ref T property, Value val, string propertyName)
	{
		setTo(val, property, propertyName);
	}
	
	T get(T)(Value val, string propertyName)
	{
		T result;
		set(result, val, propertyName);
		return result;
	}
	
	void setTo(T)(Value val, ref T property, string propertyName)
	{		
		// First - check if the property is specified in the sceme file:
		// Construct default if nothing specified.
		// Built-in types and struct are automatically initialized,
		// so we only need to instanciate classes.
		if (!val.isSpecified(propertyName))
		{	
			static if (is(T == class))
				property = new T();
			return;
		}
		
		// Next - get the corresponding value (built-in, array or object)
		auto subValue = val.getChild(propertyName);
		
		// Finally - assign it to the property accordingly
		static if (isBoolean!T || isIntegral!T || isFloatingPoint!T || isSomeString!T)
		{
			property = subValue.get!T;
		}
		else static if (is(T : Deserializable))
		{
			property = createObject!T(subValue);
		}
		else static if (isArray!T)
		{			
			foreach (elem; subValue.getArray)
			{
				property ~= createObject!(ElementType!T)(elem);
			}
		}
		else static if (is(T == Vector) || is(T == Color))
		{
			property = T(subValue.getValues[0].get!double,
						subValue.getValues[1].get!double,
						subValue.getValues[2].get!double);
		}
		else
			static assert(0, "Unsupported type!");
	}
	
protected:
	
	T createObject(T)(Value v)
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

private Value makeVal(JSONValue json) { return new JsonValueWrapper(json); }

private Value makeVal(Tag sdl) { return new SdlValueWrapper(sdl); }

interface Value
{
	final T get(T)()
	{
		static if (isBoolean!T) return getBool();
		else static if (isIntegral!T) return to!T(getInt());
		else static if (isFloatingPoint!T) return to!T(getFloat());
		else static if (isSomeString!T) return to!T(getString());
		else static assert(0, "Type not supported)");
	}

	/// Note: Only available for top-level objects/tags
	string getType();

	bool isSpecified(string propertyName);

	Value getChild(string propertyName);

	Value[] getArray();
	sdlang.Value[] getValues();

protected:
	bool getBool();
	long getInt();
	double getFloat();
	string getString();
}

class JsonValueWrapper : Value
{
	this(JSONValue v) { json = v; }

	override string getType() 
	{
		return json["type"].str;
	}

	override bool isSpecified(string propertyName)
	{
		return (propertyName in json.object) != null;
	}

	override Value getChild( string propertyName)
	{
		return new JsonValueWrapper(json[propertyName]);
	}

	override Value[] getArray()
	{
		Value[] result;

		foreach (subJson; json.array)
			result ~= new JsonValueWrapper(subJson);

		return result;
	}

	override sdlang.Value[] getValues()
	{
		sdlang.Value[] result;
		
		foreach (subJson; json.array)
			result ~= sdlang.Value(number(subJson));
		
		return result;
	}

protected:
	override bool getBool()
	{
		return boolean(json);
	}

	override long getInt()
	{
		return to!long(number(json));
	}

	override double getFloat()
	{
		return number(json);
	}

	override string getString()
	{
		return json.str;
	}

private:
	JSONValue json;

	static double number(JSONValue json)
	{
		switch (json.type)
		{
			case JSON_TYPE.FLOAT: return json.floating;
			case JSON_TYPE.INTEGER:
			case JSON_TYPE.UINTEGER: return json.integer;
			default: assert(0);
		}
	}

	static bool boolean(JSONValue json)
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
	this(Tag v) { tag = v; }

	override string getType() 
	{
		return tag.name;
	}
	
	override bool isSpecified(string propertyName)
	{
		return propertyName in tag.tags;
	}
	
	override Value getChild( string propertyName)
	{
		return new SdlValueWrapper(tag.tags[propertyName][0]);
	}
	
	override Value[] getArray()
	{
		Value[] result;

		foreach(subTag; tag.tags)
			result ~= new SdlValueWrapper(subTag);

		return result;
	}

	override sdlang.Value[] getValues()
	{
		sdlang.Value[] result;
		
		foreach(subTag; tag.values)
			result ~= subTag;
		
		return result;
	}
	
protected:
	override bool getBool()
	{
		return tag.values[0].get!bool;
	}
	
	override long getInt()
	{
		return tag.values[0].get!long;
	}
	
	override double getFloat()
	{
		return tag.values[0].get!double;
	}
	
	override string getString()
	{
		return tag.values[0].get!string;
	}

private:
	Tag tag;

	static void print(Tag tag)
	{
		import std.stdio;
		writeln(tag.name);
		
		foreach(t; tag.tags)
			print(t);
	}
}