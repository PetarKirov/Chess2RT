﻿module rt.environment;

import rt.importedtypes, rt.color, rt.sceneloader;

class Environment : Deserializable
{
	Color getEnvironment(const Vector dir) const
	{
		return Color(0, 0, 0);
	}

	void deserialize(Value val, SceneLoadContext context)
	{
	}
}

