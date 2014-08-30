module util.factory2;

import std.algorithm;

T makeInstanceOf(T)(string derivedClassName) if (is(T == class))
{
	string suffix = "." ~ derivedClassName;

	foreach (m; ModuleInfo)
	{
		assert(m);
        foreach (c; m.localClasses)
        {
            if (c.name.endsWith(suffix))
			{
				assert(c.isDerivedFrom(T.classinfo));
				return cast(T)c.create();
			}
        }
	}

	return null;
}

ClassInfo[] getBaseClasses(ClassInfo c) pure @safe nothrow
{
	ClassInfo[] result;

	while (c)
	{
		result ~= c;
		c = c.base;
	}

	return result;
}

bool isDerivedFrom(ClassInfo type_, const ClassInfo from) pure @safe nothrow @nogc
{
	while (type_)
	{
		if (type_.name == from.name) return true;
		type_ = type_.base;
	}

	return false;
}