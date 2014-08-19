module rt.environment;

import rt.importedtypes, rt.color;

abstract class Environment
{
	Color getEnvironment(const Vector dir)
	{
		return Color(0, 0, 0);
	}
}

