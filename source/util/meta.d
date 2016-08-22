module util.meta;

mixin template TemplateSwitchOn(Enum, alias functionToCall)
    if (is(Enum == enum))
{
    import std.traits : EnumMembers;

    auto call(FArgs...)(Enum enumCase, FArgs args)
    {
        final switch (enumCase)
        {
            foreach (EnumMember; EnumMembers!Enum)
                case EnumMember:
                return functionToCall!(EnumMember)(args);
        }

        assert (0);
    }
}

template PrepareTailFor(alias Templ, TailArgs...)
{
    alias PrepareTailFor(HeadArgs...) = Templ!(HeadArgs, TailArgs);
}

template PrepareHeadFor(alias Templ, HeadArgs...)
{
    alias PrepareHeadFor(TailArgs...) =  Templ!(HeadArgs, TailArgs);
}

/// Used to disambiguate a type where an expression is expected
alias Type(T...) = T[0];
