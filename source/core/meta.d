///
module core.meta;

template DerivedFrom(T)
{
    import std.meta : AliasSeq, Filter, staticMap;
    import std.traits : moduleName;

    static if (is(T == class))
    {
        mixin ("import " ~ moduleName!T ~ ";");

        alias DerivedFrom = Filter!(
            isDerivedFrom!T,
            staticMap!(
                TypeFromStr,
                Filter!(
                    isType,
                    __traits(allMembers, mixin(moduleName!T))
                )
            )
        );

        template isDerivedFrom(U)
        {
            enum isDerivedFrom(T) = is(T == class) && is(U == class) && is(T : U);
        }

        enum isType(string symName) = is(TypeFromStr!symName);

        template TypeFromStr(string str)
        {
            mixin ("alias TypeFromStr = " ~ str ~ ";");
        }
    }
    else
        alias DerivedFrom = AliasSeq!();

}

template TypesToStrings(T...)
{
    import std.meta : AliasSeq;

    static if (T.length == 0)
        alias TypesToStrings = AliasSeq!("");

    else static if (T.length == 1)
        alias TypesToStrings = AliasSeq!(T[0].stringof);

    else
        alias TypesToStrings = AliasSeq!(T[0].stringof,
            TypesToStrings!(T[1 .. $]));
}

unittest
{
    import std.meta : AliasSeq;
    static assert (TypesToStrings!int[0] == "int");

    alias TL1 = AliasSeq!(short, float, byte);
    static assert (TypesToStrings!TL1[0] == "short");
    static assert (TypesToStrings!TL1[1] == "float");
    static assert (TypesToStrings!TL1[2] == "byte");
}
