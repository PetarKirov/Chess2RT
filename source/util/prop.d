module util.prop;

import std.array;
import util.enumutils;
import std.typecons, std.traits, std.typetuple;

mixin template ObservableProperty(T, string propertyName,
        string setter, string init_value)
{
    mixin (property_impl!(T, propertyName, Access.ReadWrite,
           setter, init_value));
}

enum Access
{
    None        = 0b00,
    ReadOnly    = 0b01,
    WriteOnly   = 0b10,
    ReadWrite   = 0b11
}

/// Creates a field and get / set methods
mixin template property(T, string propertyName,
    Access access = Access.ReadWrite)
{
    mixin (property_impl!(T, propertyName, access));
}

template property_impl(T, string propertyName, Access access,
    string setter = "", string init_value = "T.init")
{
    enum property_impl = field ~
        (access.hasFlags(Access.ReadOnly)? readFunc : "") ~
        (access.hasFlags(Access.WriteOnly)? writeFunc : "");

    enum typeStr = T.stringof;

    enum field = q{
            private T _propertyName = init_value;
    }.replaceFirst("T", typeStr)
     .replace("propertyName", propertyName)
     .replace("init_value", init_value);

    enum readFunc = q{
        @property
        T propertyName()
        {
                return _propertyName;
        }
    }.replaceFirst("T", typeStr)
     .replace("propertyName", propertyName);

    enum writeFunc = q{
        @property
        void propertyName(T newVal)
        {
                _propertyName = newVal;
                setter;
        }
    }.replaceFirst("T", typeStr)
     .replace("propertyName", propertyName)
     .replace("setter", setter);
}

private:
alias Element(T) = T;
alias Array(T) = T[];
alias AA(T) = T[string];

mixin template generateMembers(alias fun, bool genGetArray, Specs...)
{
    alias rep = generateMembers_impl!(fun, false, Specs);

    mixin(rep.generate());

    static if (genGetArray)
    {
        fun!T getArray(T)()
        {
            import std.traits;

            foreach (spec; rep.specsTuple)
                static if (isImplicitlyConvertible!(T, spec.Type))
                    return mixin(spec.name);

            static assert(0, "Unknown type!");
        }

        static bool canBeStored(T)()
        {
            return rep.canBeStored!T;
        }
    }
}

template generateMembers_impl(alias fun, bool makeGetArray, Specs...)
{
    template canBeStored(T)
    {
        import std.traits, std.typetuple;
        enum isDerivedFromT(Other) = isImplicitlyConvertible!(Other, T);

        enum canBeStored = anySatisfy!(isDerivedFromT, Tuple!Specs.Types);
    }

    alias specsTuple = parseSpecs!Specs;
    alias Types = Tuple!(Specs).Types;

    string generate()
    {
        string result;
        foreach(spec; specsTuple)
            result ~= fun!(spec.Type).stringof ~ " " ~ spec.name ~ ";\n";

        return result;
    }
}

template FieldSpec(T, string s = "")
{
    alias Type = T;
    alias name = s;
}

//Taken from std.typecons
template parseSpecs(Specs...)
{
    static if (Specs.length == 0)
    {
        alias parseSpecs = TypeTuple!();
    }
    else static if (is(Specs[0]))
    {
        static if (is(typeof(Specs[1]) : string))
        {
            alias parseSpecs = TypeTuple!(FieldSpec!(Specs[0 .. 2]),
                parseSpecs!(Specs[2 .. $]));
        }
        else
        {
            alias parseSpecs = TypeTuple!(FieldSpec!(Specs[0]),
                parseSpecs!(Specs[1 .. $]));
        }
    }
    else
    {
        static assert(0, "Attempted to instantiate Tuple with an " ~
            "invalid argument: "~ Specs[0].stringof);
    }
}
