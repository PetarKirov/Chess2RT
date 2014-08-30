module rt.sceneloader;

import std.json, std.file, std.conv, std.traits, std.range, std.exception;

import rt.exception, rt.scene, rt.importedtypes, rt.color;
import util.factory2;

alias Value = JSONValue;

// Classes that support JSON deserializing should implement this interface.
interface Deserializable
{
	void deserialize(Value val, SceneLoadContext context);
}

Scene parseSceneFromFile(string fileName)
{
	try
	{
		return fileName
			.readText
		 	.parseJSON
		 	.deserialize(new SceneLoadContext());
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

Scene deserialize(Value val, SceneLoadContext context)
{
	auto scene = new Scene();

	context.scene = scene;
	context.set(scene.settings, val, "GlobalSettings");
	context.set(scene.camera, val, "Camera");
	context.set(scene.environment, val, "Environment");
	context.set(scene.lights, val, "Lights");
	context.set(scene.geometries, val, "Geometries");
	context.set(scene.textures, val, "Textures");
	context.set(scene.shaders, val, "Shaders");
	context.set(scene.nodes, val, "Nodes");

	return scene;
}

class SceneLoadContext
{
	Scene scene;
	alias get this;
	NamedEntities get() { return scene.namedEntities; }	

	void set(T)(ref T property, Value val, string propertyName)
	{
		// First - check if the property is specified in the JSON:
		// Construct default if nothing specified.
		// Built-in types and struct are automatically initialized,
		// so we only need to instanciate classes.
		// Note: For compatability with Phobos DMD2.065
		// Note: we're looking in .object, instead of the json itself.
		if (propertyName !in val.object)
		{	
			static if (is(T == class))
				property = new T();
			return;
		}
		
		// Next - get the corresponding value (built-in, array or object)
		auto subJson = val[propertyName];
		
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

	private T createObject(T)(Value val)
	{
		T obj = makeInstanceOf!T(val["type"].str);
		obj.deserialize(val, this);

		static if (NamedEntities.canBeStored!T)
			if ("name" in val.object)
			{
				string name = val["name"].str;
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
