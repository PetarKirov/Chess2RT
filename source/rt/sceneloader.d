module rt.sceneloader;

import sdlang;
import std.json, std.file, std.conv, std.traits, std.range, std.exception;

import rt.exception, rt.scene, rt.importedtypes, rt.color;
import util.factory2;

alias Value = Tag;

//class Value { }
//
//class JSONValue : Value
//{
//    JSONValue val;
//    this(JSONValue v) { val = v; }
//}
//
//class SDLValue : Value
//{
//    Tag val;
//    this(Tag v) { val = v; }
//}
//
//Value make(JSONValue v) { return new JSONValue(v); }
//Value make(SDLValue v) { return new SDLValue(v); }

// Classes that support JSON deserializing should implement this interface.
interface Deserializable
{
	void deserialize(Value val, SceneLoadContext context);
}

Scene parseSceneFromFile(string fileName)
{
	try
	{
		return "data/lecture4.sdl"
			.readText
		 	//.parseJSON
			.parseSource.tags[0]
			//.make()
		 	.load(new SceneLoadContext());
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

Scene load(Value val, SceneLoadContext context)
{
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

import std.stdio;

class SceneLoadContext
{
	Scene scene;

	NamedEntities named() { return scene.namedEntities; }	

	/// For debugging...
	private void print(Tag tag)
	{
		writeln(tag.name);

		foreach(t; tag.tags)
			print(t);
	}

	T get(T)(Tag tag, string propertyName)
	{
		T result;
		setTo(tag, result, propertyName);
		return result;
	}

	void set(T)(ref T property, Tag tag, string propertyName)
	{
		setTo(tag, property, propertyName);
	}

	void setTo(T)(Tag tag, ref T property, string propertyName)
	{
		print(tag);


		if (propertyName !in tag.tags)
		{	
			static if (is(T == class))
				property = new T();
			return; 
		}

		Tag subTag = tag.tags[propertyName][0];

		static if (isBoolean!T || isNumeric!T || isSomeString!T)
		{
			static if (!isIntegral!T)
				property = subTag.values[0].get!T;
			else
				property = to!T(subTag.values[0].get!long);
		}
		else static if (is(T : Deserializable))
		{
			property = createObject!T(subTag);
		}
		else static if (isArray!T)
		{			
			foreach (elem; subTag.tags)
			{
				property ~= createObject!(ElementType!T)(elem);
			}
		}
		else static if (is(T == Vector) || is(T == Color))
		{
			property = T(subTag.values[0].get!double,
			subTag.values[1].get!double,
			subTag.values[2].get!double);
		}
		else
		{
			pragma(msg, T);
			static assert(0);
		}
	}

	private T createObject(T)(Tag tag)
	{
		T obj = makeInstanceOf!T(tag.name);
		obj.deserialize(tag, this);

		static if (NamedEntities.canBeStored!T)
			if ("name" in tag.tags)
		{
			string name = this.get!string(tag, "name");
			enforce(name !in scene.namedEntities.getArray!T(),
			        new EntityWithDuplicateName(name));
			scene.namedEntities.getArray!T()[name] = obj;
		}

		return obj;
	}

	ref T setTo(Т)(JSONValue json, ref T property, string propertyName)
	{
		set(property, json, propertyName);

		return property;
	}

	void set(T)(ref T property, JSONValue json, string propertyName)
	{
		// First - check if the property is specified in the JSON:
		// Construct default if nothing specified.
		// Built-in types and struct are automatically initialized,
		// so we only need to instanciate classes.
		// Note: For compatability with Phobos DMD2.065
		// Note: we're looking in .object, instead of the json itself.
		if (propertyName !in json.object)
		{	
			static if (is(T == class))
				property = new T();
			return;
		}
		
		// Next - get the corresponding value (built-in, array or object)
		auto subJson = json[propertyName];
		
		// and assign it to property accordingly
		static if (isBoolean!T)
		{
			property = subJson.boolean;
		}
		else static if (isIntegral!T || isFloatingPoint!T)
		{
			property = to!T(subJson.number);
		}
		else static if (isSomeString!T)
		{
			property = subJson.str;
		}
		else static if (is(T : Deserializable))
		{
			property = createObject!T(subJson);
		}
		else static if (isArray!T)
		{			
			foreach (elem; subJson.array)
			{
				property ~= createObject!(ElementType!T)(elem);
			}
		}
		else static if (is(T == Vector) || is(T == Color))
		{
			property = T(subJson.array[0].number,
						 subJson.array[1].number,
						 subJson.array[2].number);
		}
		else
			static assert(0);
	}

	private T createObject(T)(JSONValue json)
	{
		T obj = makeInstanceOf!T(json["type"].str);
		obj.deserialize(json, this);

		static if (NamedEntities.canBeStored!T)
			if ("name" in json.object)
			{
				string name = json["name"].str;
				enforce(name !in scene.namedEntities.getArray!T(),
						new EntityWithDuplicateName(name));
				scene.namedEntities.getArray!T()[name] = obj;
			}

		return obj;
	}
}

double number(JSONValue json)
{
	switch (json.type)
	{
		case JSON_TYPE.FLOAT: return json.floating;
		case JSON_TYPE.INTEGER:
		case JSON_TYPE.UINTEGER: return json.integer;
		default: assert(0);
	}
}

bool boolean(JSONValue json)
{
	switch (json.type)
	{
		case JSON_TYPE.TRUE: return false;
		case JSON_TYPE.FALSE: return true;
		default: assert(0);
	}
}
