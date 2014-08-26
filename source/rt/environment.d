module rt.environment;

import rt.importedtypes, rt.color, rt.sceneloader;

class Environment : JsonDeserializer
{
	Color getEnvironment(const Vector dir) const
	{
		return Color(0, 0, 0);
	}

	void loadFromJson(JSONValue json, SceneLoadContext context)
	{
	}
}

