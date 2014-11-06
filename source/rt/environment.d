module rt.environment;

import rt.importedtypes, rt.color, rt.sceneloader;

class Environment : Deserializable
{
	Color getEnvironment(const Vector dir) const @nogc
	{
		return Color(0, 0, 0);
	}

	void deserialize(const Value val, SceneLoadContext context)
	{
	}
}

