module rt.sceneloader;

import std.file, std.json, std.traits, std.container.util;
import std.stdio;

import rt.exception;
import rt.scene, rt.globalSettings, rt.camera, rt.environment, rt.shader, rt.texture, rt.geometry, rt.node, rt.importedtypes, rt.light, rt.color;

interface JsonDeserializer
{
	void loadFromJson(JSONValue json, SceneLoadContext context);
}

Scene parseSceneFromFile(string fileName)
{
	auto text = fileName.readText;
	writeln("readText");
	
	auto json = text.parseJSON;
	writeln("parseJSON");
	
	return loadFromJson(json, new SceneLoadContext());
}

class SceneLoadContext
{
	Light[string] lights;
	Texture[string] textures;
	Shader[string] shaders;
	Geometry[string] geometries;
	Node[string] nodes;

	Object[string] other;

	ref T[string] getArray(T)()
	{
			 static if (is(T == Light)) return lights;
		else static if (is(T == Texture)) return textures;
		else static if (is(T == Shader)) return shaders;
		else static if (is(T == Geometry)) return geometries;
		else static if (is(T == Node)) return nodes;
		else static if (is(T == Object)) return other;
		else static assert(0);
	}

	void set(T)(ref T property, JSONValue json, string propertyName)
	{
		import std.traits, std.conv;
		
		if (propertyName !in json)
		{
			// Make default if nothing specified.
			// Built-in types and struct are automatically initialized,
			// so we only need to instanciate classes.
			
			static if (is(T == class))
				property = new T();
			return;
		}
		
		auto subJson = json[propertyName];
		
		static if (isIntegral!T || isBoolean!T)
		{
			property = to!T(subJson.integer);
		}
		else static if (isFloatingPoint!T)
		{
			property = to!T(subJson.number);
		}
		else static if (isSomeString!T)
		{
			property = subJson.str;
		}
		else static if (is(T : JsonDeserializer))
		{
			property = parseObj!T(subJson, this);
		}
		
		else static if (isArray!T)
		{
			import std.range;
			alias E = ElementType!T;
			
			foreach (elem; subJson.array)
			{
				property ~= parseObj!E(elem, this);
			}
		}
		
		else static if (is(T == Vector))
		{
			auto arr = subJson.array;
			property = Vector(arr[0].number, arr[1].number, arr[2].number);
		}
		
		else static if (is(T == Color))
		{
			auto arr = subJson.array;
			property = Color(arr[0].number, arr[1].number, arr[2].number);
		}
		
		else
			static assert(0);
	}
}

T parseObj(T)(JSONValue json, SceneLoadContext context)
{
	string type = json["type"].str;
	string fullType = moduleName!T ~ "." ~ type;

	T obj = cast(T)Object.factory(fullType);

	static if (hasMember!(T, "name"))
	{
		string name = json["name"].str;
		obj.name = name;
		context.getArray!T()[name] = obj;
		writeln("With name: ", context.getArray!T());
		writeln("Textures: ", context.textures);
	}
	else
	{
		context.getArray!Object()[type] = obj;
		writeln("No name: ", context.getArray!Object());
	}

	obj.loadFromJson(json, context);

	return obj;
}

double number(JSONValue json)
{
	if (json.type == JSON_TYPE.FLOAT)
		return json.floating;
	else
		return json.integer;
}