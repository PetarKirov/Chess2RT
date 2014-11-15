/*
 * Mixin strings for pretty printing
 * Place this in your base class void toString(sink) function:
 * 
 * ----
 * import util.prettyprint;
 * mixin(toStrBaseBody);
 * ----
 *
 * Place this in your derived classes' void toString(sink) function:
 * 
 * ----
 * import util.prettyprint;
 * mixin(toStrBody);
 * ----
 */
module util.prettyprint;

enum toStrBaseBody = q{
	import std.conv : to;

	foreach(i, mem; FieldNameTuple!(typeof(this)))
	{
		sink(mem);
		sink(": ");
		sink(to!string(this.tupleof[i]));
		sink(", ");
	}
};


enum toStrBody = q{
	import std.conv : to;
	import std.traits : Unqual;
	
	sink(typeid(this).toString());

	sink(": { ");

	// Call the parent class toString method if the parent
	// class is user-defined.
	static if(!is(Unqual!(typeof(super)) == Object))
		super.toString(sink);
	
	foreach(i, mem; FieldNameTuple!(typeof(this)))
	{
		static if (i > 0)
			sink(", ");

		sink(mem);
		sink(": ");

		// Workarounds the bug that calling to!string on null Rebindable
		// results in segfault
		static if (__traits(compiles, this.tupleof[i] is null))
			if (this.tupleof[i] is null)
			{
				sink("null");
				continue;
			}

		sink(to!string(this.tupleof[i]));
	}
	
	sink("}");
};

// For compatibility with phobos older than 2.067:
import std.typetuple : staticMap;

private enum NameOf(alias T) = T.stringof;
template FieldNameTuple(T)
{
	static if (is(T == struct) || is(T == union))
		alias FieldNameTuple = staticMap!(NameOf, T.tupleof[0 .. $ - isNested!T]);
	else static if (is(T == class))
		alias FieldNameTuple = staticMap!(NameOf, T.tupleof);
	else
		alias FieldNameTuple = TypeTuple!"";
}