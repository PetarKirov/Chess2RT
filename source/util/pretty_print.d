/*
 * Mixin strings for pretty printing
 * Place this in your base class void toString(sink) function:
 *
 * ----
 * import util.prettyprint;
 * printBaseMembers!(typeof(this), sink)(this);
 * ----
 *
 * Place this in your derived classes' void toString(sink) function:
 *
 * ----
 * import util.prettyprint;
 * printMembers!(typeof(this), sink)(this);
 * ----
 */
module util.prettyprint;

enum whitespace = "\n";
enum nest_ws = "    ";

//mixin template PrintMix(T)
//{
//  import std.conv : to;
//  import std.traits : Unqual, FieldNameTuple;
//
//  printCore!(typeof(this), sink, "\n")(this);
//}

void printBaseMembers(T, alias sink, string ws = "\n")(const T thiz)
{
    printCore!(T, sink, whitespace)(thiz);
}

void printMembers(T, alias sink, string ws = "\n")(const T thiz)
{
    import std.traits : Unqual, BaseClassesTuple;

    sink(T.stringof);

    sink(whitespace);
    sink("{");
    sink(whitespace);

    // Call the parent class toString method if the parent
    // class is user-defined.
    alias BaseOfT = BaseClassesTuple!(T)[0];

    pragma (msg, T, " ", BaseOfT);

    typeof(sink) inner_sink = msg => (sink(nest_ws), sink(msg));

    static if(!is(BaseOfT == Object) && !hasMemberAttr!(thiz, BaseOfT, "toString", DontPrint))
    {
        callBaseMethod!("toString")(thiz, inner_sink);
        sink(",");
        sink(whitespace);
    }

    printCore!(T, inner_sink, whitespace)(thiz);

    sink(whitespace);
    sink("},");
    sink(whitespace);
}

auto callBaseMethod(string MethodName, Klass, Args...)(inout Klass thiz, Args args)
{
    import std.traits : BaseClassesTuple;
    alias BaseKlass = BaseClassesTuple!(Klass)[0];
    return mixin(`thiz.` ~ BaseKlass.stringof ~ `.` ~ MethodName ~ "(args)");
}

enum DontPrint;

template hasAttribute(alias Sym, Attr)
{
    enum bool hasAttribute = find_out();

    static bool find_out()
    {
        foreach(a; __traits(getAttributes, Sym))
        {
            if (is(a == Attr))
                return true;
        }
        return false;
    }
}

import std.traits : hasUDA;

enum hasIdxMemberAttr(T, size_t memberIdx, Attr) =
    hasUDA!(T.tupleof[memberIdx], Attr);

enum hasMemberAttr(alias Sym, T, string MemberName, Attr) = hasUDA!(mixin(`Sym.` ~ T.stringof ~ `.` ~ MemberName), Attr);

void printCore  (T, alias sink, string ws = "\n")(const T thiz)
{
    import std.conv : to;
    import std.traits : FieldNameTuple;
    import std.array : appender;

    char[512] line;
    auto buf = appender(line);
    buf.clear();

    enum printable(size_t memberIdx) = !hasIdxMemberAttr!(T, memberIdx, DontPrint);

    bool anyMemberPrinted = false;

    foreach(i, memberName; FieldNameTuple!T)
    {
        static if (!printable!i)
            continue;

        if (i > 0 && anyMemberPrinted)
        {
            buf.put(",");
            buf.put(ws);
            sink(buf.data);
            buf.clear();
        }

        anyMemberPrinted = true;

        buf.put(memberName);
        buf.put(": ");

        // Workarounds the bug that calling to!string on null Rebindable
        // results in segfault
        static if (__traits(compiles, thiz.tupleof[i] is null))
        if (thiz.tupleof[i] is null)
        {
            buf.put("null");
            continue;
        }

        static if (__traits(compiles, { thiz.tupleof[i].toString(sink); }))
        {
            thiz.tupleof[i].toString((msg)
            {
                if (msg == ws)
                {
                    buf.put(ws);
                    sink(buf.data);
                    buf.clear();
                }
                else
                    buf.put(msg);
            });
        }
        else
            buf.put(to!string(thiz.tupleof[i]));
    }

    sink(buf.data);
}

