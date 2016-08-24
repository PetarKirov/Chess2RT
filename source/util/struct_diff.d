module util.struct_diff;

import std.meta : staticMap, staticIndexOf;
import std.traits : Fields, FieldNameTuple;
import std.typecons : Tuple, Nullable;

alias DiffOf(Field) = Tuple!(Field, "before", Field, "after");

alias DiffRecordOf(T) = Nullable!(DiffOf!T);

alias Records(S) = staticMap!(DiffRecordOf, Fields!S);

enum indexOfMember(S, string memberName) =
	staticIndexOf!(memberName, FieldNameTuple!S);

struct Diff(S) if (is(S == struct))
{
	Records!S records;

	bool anyChanges()
	{
		bool changed;

		foreach (record; records)
			if (!record.isNull)
				changed = true;

		return changed;
	}

	bool hasChanged(string fieldName)()
	{
		enum idx = indexOfMember!(S, fieldName);
		return !records[idx].isNull;
	}
}

///
Diff!T struct_diff(T)(const T old, const T new_) if (is(T == struct))
{
	Diff!T result;

	foreach (idx, newFieldValue; new_.tupleof)
	{
		alias FieldType = typeof(T.tupleof[idx]);

		if (newFieldValue != old.tupleof[idx])
			result.records[idx] =
				DiffOf!FieldType(old.tupleof[idx], newFieldValue);
	}

	return result;
}

///
unittest
{
	struct Point
	{
		int x, y;
	}

	auto a = Point(2, 3), b = Point(2, 3);
	auto c = Point(1, 2), d = Point(1, 3);
	auto e = Point(1, 2), f = Point(3, 2);

	auto diffAB = struct_diff(a, b);
	assert(!diffAB.anyChanges);

	auto diffCD = struct_diff(c, d);
	assert(diffCD.anyChanges);
	assert(!diffCD.hasChanged!"x");
	assert(diffCD.hasChanged!"y");


	auto diffEF = struct_diff(e, f);
	assert(diffEF.anyChanges);
	assert(diffEF.hasChanged!"x");
	assert(!diffEF.hasChanged!"y");
}

///
string printDiff(T)(const T before, const T after)
	if (is(T == struct))
{
	import std.algorithm : max;
	import std.conv : to;
	import std.format : format;
	import std.range : repeat;
	import std.string : center;

	auto diff = struct_diff(before, after);

	size_t maxLen;
	
	foreach (record; diff.records)
		maxLen = max(maxLen, record.isNull ? 3 : 
			max(record.before.to!string.length, record.after.to!string.length));

	string result;

	result ~= "+%s+\n".format('-'.repeat(maxLen * 2 + 1));
	result ~= "|%s|%s|\n".format("before".center(maxLen), "after".center(maxLen));
	result ~= "|%s|%s|\n".format('-'.repeat(maxLen), '-'.repeat(maxLen));

	foreach (record; diff.records)
		if (record.isNull)
			result ~= "|%1$s|%1$s|\n".format("[unchanged]".center(maxLen));
		else
			result ~= "|%s|%s|\n".
				format(
					record.before.to!string.center(maxLen),
					record.after.to!string.center(maxLen));

	result ~= "+%s+\n".format('-'.repeat(maxLen * 2 + 1));
	return result;
}

///
unittest
{
	struct Person
	{
		string firstName;
		string lastName;
		int age;
		string address;
	}

	auto p1 = Person("John", "Doe", 27, "new york");
	auto p2 = Person("Jane", "Doe", 23, "north america, usa, new jersey");

	import std.stdio;
	writeln(printDiff(p1, p2));
}