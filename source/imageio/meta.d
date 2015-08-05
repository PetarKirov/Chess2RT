module imageio.meta;

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
	alias PrepareHeadFor(TailArgs...) = Templ!(HeadArgs, TailArgs);
}

To as(To, From)(From to_convert)
{
	import std.traits : isArray;

	static if (is(To == T[], T) && is(From == F[], F))
		return (cast(To)to_convert);

	else static if (!isArray!From && !isArray!To)
		return cast(To)to_convert;

	else
		static assert (0, "Unsupported types: " ~ From.stringof ~ " and " ~ To.stringof ~
			(is(To == T1[], T1) && is(From == F1[], F1) && T1.sizeof == F1.sizeof).stringof);
}

ubyte[n] asBytes(T, size_t n = T.sizeof)(const T value)
{
	T[1] tmp = value;
	return cast(ubyte[n])tmp;
}