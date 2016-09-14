module util.factory2;

import std.algorithm : endsWith;

T makeInstanceOf(T)(string derivedClassName) if (is(T == class))
{
    string suffix = "." ~ derivedClassName;

    foreach (m; ModuleInfo)
    {
        if (!m) continue;
        foreach (c; m.localClasses)
        {
            if (c.name.endsWith(suffix))
            {
                import std.format : format;
                assert(c.isDerivedFrom(T.classinfo),
                    "%s is not derived from %s!".format(
                        c.name, T.stringof
                    )
                );
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
