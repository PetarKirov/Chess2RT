/*
 * Mixin strings for prettyr printing
 * Place this in your base class void toString(sink) function:
 * 
 * ----
 * import util.prettyPrint;
 * mixin(toStrBaseBody);
 * ----
 *
 * Place this in your derived classes' void toString(sink) function:
 * 
 * ----
 * import util.prettyPrint;
 * mixin(toStrBody);
 * ----
 */
module util.prettyPrint;

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

	static if(!is(Unqual!(typeof(super)) == Object))
		super.toString(sink);
	
	foreach(i, mem; FieldNameTuple!(typeof(this)))
	{
		static if (i > 0)
		{
			sink(", ");
		}

		sink(mem);
		sink(": ");
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