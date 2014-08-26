module rt.sceneloader;

import std.file, std.traits;
public import std.json;
import std.stdio;

import rt.exception;
import rt.scene, rt.globalsettings, rt.camera, rt.environment, rt.shader, rt.texture, rt.geometry, rt.node, rt.importedtypes, rt.light, rt.color;

interface JsonDeserializer
{
	void loadFromJson(JSONValue json, SceneLoadContext context);
}

Scene parseSceneFromFile(string fileName)
{
	try
	{
		return fileName
			.readText
		 	.parseJSON
		 	.loadFromJson(new SceneLoadContext());
	}
	catch (FileException fEx)
	{
		throw new SceneNotFoundException();
	}
	catch (JSONException jsonEx)
	{
		throw new InvalidSceneException("Invalid json in scene file!", jsonEx);
	}
}

class SceneLoadContext
{
	Scene scene;
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
		
		if (propertyName !in json.object)
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
			property = to!T(subJson.number);
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
			double r = arr[0].number;
			double g = arr[1].number;
			double b = arr[2].number;

			property = Color(r, g, b);
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
  auto type = json.type;

  if (type == JSON_TYPE.FLOAT)
	  return json.floating;
  else
	  return json.integer;
}