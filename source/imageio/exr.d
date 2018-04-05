///
module imageio.exr;

import std.traits : isScalarType;
import gfm.math : v2f = vec2f, v3f = vec3f, m33f = mat3f, m44f = mat4f, box2i, box2f;

private void infuse(T)(ref T where, ref const(ubyte)[] bytes, size_t extra = 0)
    if (is(T == struct) || isScalarType!T)
{
    assert (bytes.length >= T.sizeof);

    auto asRawBytes = (cast(ubyte*)&where)[0 .. T.sizeof + extra];
    asRawBytes[] = bytes[0 .. T.sizeof + extra];
    bytes = bytes[T.sizeof + extra .. $];
}

const(T)* peek(T)(const(ubyte)[] bytes)
    if (is(T == struct))
{
    assert (bytes.length >= T.sizeof);

    return (cast(const(T)[])bytes[0 .. T.sizeof]).ptr;
}

auto read(T)(ref const(ubyte)[] bytes, size_t count = 0)
    //if (is(T == struct) || isScalarType!T)
{
    assert (bytes.length >= T.sizeof);

    static if (is(T == E[], E))
    {
        assert (count > 0);
        auto res = cast(E[])bytes[0 .. E.sizeof * count];
        bytes = bytes[E.sizeof * count .. $];
        return res;
    }
    else
    {
        assert (count == 0);
        auto result = (cast(const(T)[])bytes[0 .. T.sizeof]).ptr;
        bytes = bytes[T.sizeof .. $];
        return result;
    }
}

string copyStringz(ref const(ubyte)[] bytes)
{
    import std.conv : to;
    import std.string : fromStringz;
    string result = fromStringz(cast(const(char)*)bytes.ptr).to!string;
    bytes = bytes[result.length + 1 .. $];
    return result;
}

ExrFile loadExr(const ubyte[] fileBytes)
{
    ExrFile result;
    const(ubyte)[] bytes = fileBytes;

    result.header.infuse(bytes);

    // Read attributes
    while (bytes.length)
    {
        if (bytes[0] == 0)
        {
            bytes = bytes[1 .. $];
            break;
        }

        auto name = copyStringz(bytes);
        auto type = copyStringz(bytes);
        auto size = *read!int(bytes);

        auto attr = AttributeBase.makeAttribute(name, type, size);

        attr.load(bytes[0 .. size]);

        bytes = bytes[size .. $];

        result.attributes[name] = attr;
    }

    // read scan offset table
    auto width = result.dataWindow().value.max.x + 1,
         height = result.dataWindow().value.max.y + 1;

    auto linesPerBlock = result.compression.value.scanLinesPerBlock;

    auto scanLines = height / linesPerBlock;
    assert (scanLines * linesPerBlock == height);

    ulong[] offsetTable = bytes.read!(ulong[])(scanLines);

    foreach (offset; offsetTable)
    {
        import std.conv : to;
        auto slice = fileBytes[offset.to!size_t .. $];
        int y = *slice.read!int;
        int lineSize = *slice.read!int;
        auto pixelData = slice[0 .. lineSize];

        import std.stdio : writefln;
        writefln("At: %s, size: %s", y, lineSize);
    }

    return result;
}

unittest
{
    import std.file : read;
    import std.stdio : writefln;

    auto exr = (cast(const(ubyte)[])read("./data/env/forest/negx.exr")).loadExr();

    writefln("%s", exr);
}

enum PixelType : int
{
    uint_,
    half_,
    float_,
    num_pixel_types
}

struct Channel
{
    PixelType type = PixelType.half_;
    bool pLinear = false;
    int xSampling = 1;
    int ySampling = 1;

    static assert (Channel.sizeof == 16);
}

struct TypeName { string name; }

@TypeName("chlist")
struct ChannelList
{
    Channel[string] channels;
}

@TypeName("chromaticities")
struct Chromaticities
{
    v2f red = v2f(0.6400f, 0.3300f);
    v2f green = v2f(0.3000f, 0.6000f);
    v2f blue = v2f(0.1500f, 0.0600f);
    v2f white = v2f(0.3127f, 0.3290f);
}

@TypeName("compression")
enum Compression : char
{
    NO_COMPRESSION  = 0,    // no compression

    RLE_COMPRESSION = 1,    // run length encoding

    ZIPS_COMPRESSION = 2,   // zlib compression, one scan line at a time

    ZIP_COMPRESSION = 3,    // zlib compression, in blocks of 16 scan lines

    PIZ_COMPRESSION = 4,    // piz-based wavelet compression

    PXR24_COMPRESSION = 5,  // lossy 24-bit float compression

    B44_COMPRESSION = 6,    // lossy 4-by-4 pixel block compression,
                    // fixed compression rate

    B44A_COMPRESSION = 7,   // lossy 4-by-4 pixel block compression,
                    // flat fields are compressed more

    DWAA_COMPRESSION = 8,       // lossy DCT based compression, in blocks
                                // of 32 scanlines. More efficient for partial
                                // buffer access.

    DWAB_COMPRESSION = 9,       // lossy DCT based compression, in blocks
                                // of 256 scanlines. More efficient space
                                // wise and faster to decode full frames
                                // than DWAA_COMPRESSION.

    NUM_COMPRESSION_METHODS // number of different compression methods
}

ubyte scanLinesPerBlock(Compression c)
{
    final switch (c) with (Compression)
    {
        case NO_COMPRESSION: return 1;
        case RLE_COMPRESSION: return 1;
        case ZIPS_COMPRESSION: return 1;
        case ZIP_COMPRESSION: return 16;
        case PIZ_COMPRESSION: return 32;
        case PXR24_COMPRESSION: return 16;
        case B44_COMPRESSION: return 32;
        case B44A_COMPRESSION: return 32;
        case DWAA_COMPRESSION: assert (0); // unknown
        case DWAB_COMPRESSION: assert (0); // unknown
        case NUM_COMPRESSION_METHODS: assert (0);
    }
}

@TypeName("envmap")
enum Envmap : char
{
    ENVMAP_LATLONG = 0,     // Latitude-longitude environment map
    ENVMAP_CUBE = 1,        // Cube map

    NUM_ENVMAPTYPES     // Number of different environment map types
}

@TypeName("lineOrder")
enum LineOrder : char
{
    INCREASING_Y = 0,   // first scan line has lowest y coordinate

    DECREASING_Y = 1,   // first scan line has highest y coordinate

    RANDOM_Y = 2,       // only for tiled files; tiles are written
                // in random order

    NUM_LINEORDERS  // number of different line orders
}

struct ExrFile
{
    FileHeader header;

    AttributeBase[string] attributes;

    auto channels()           const { return attributes["channels"].toTypedAttr!(ChannelList); }
    auto compression()        const { return attributes["compression"].toTypedAttr!(Compression); }
    auto dataWindow()         const { return attributes["dataWindow"].toTypedAttr!(box2i); }
    auto displayWindow()      const { return attributes["displayWindow"].toTypedAttr!(box2i); }
    auto lineOrder()          const { return attributes["lineOrder"].toTypedAttr!(LineOrder); }
    auto pixelAspectRatio()   const { return attributes["pixelAspectRatio"].toTypedAttr!(float); }
    auto screenWindowCenter() const { return attributes["screenWindowCenter"].toTypedAttr!(v2f); }
    auto screenWindowWidth()  const { return attributes["screenWindowWidth"].toTypedAttr!(float); }

    string toString() const
    {
        import std.algorithm.iteration : map, joiner;
        import std.conv : to;

        return header.toString() ~ "\n" ~
            attributes
                .byValue
                .map!(to!string)
                .joiner("\n").to!string;
    }
}

struct FileHeader
{
    enum int MAGIC = 20000630;

    int magic;
    union
    {
        uint versionAsInt;
        import std.bitmanip : bitfields;
        mixin (bitfields!(
            ubyte, "versionNumber", 8,
            bool, "tiled", 1,
            bool, "longNames", 1,
            bool, "nonImageParts", 1,
            bool, "multiPartFile", 1,
            uint, "", 20
        ));
    }

    static assert (typeof(this).sizeof == 8);

    string toString() const
    {
        import std.format : format;
        return "magic { %s }, header { version: %s, tiled: %s, longNames: %s, nonImageParts: %s, multiPartFile: %s }"
            .format(magic, versionNumber, tiled, longNames, nonImageParts, multiPartFile);
    }
}

class AttributeBase
{
    string name;
    string type;
    int size;

    abstract void load(const(ubyte)[] bytes);

    abstract override string toString() const;

    inout(Attribute!T) toTypedAttr(T)() inout
    {
        import std.format : format;
        assert (typeName!T == this.type, "Expected %s, got: %s!".format(typeName!T, this.type));
        return cast(Attribute!T)this;
    }

    static AttributeBase makeAttribute(string name, string type, int size)
    {
        alias TaggedTypesInThisModule = getSymbolsByUDA!(mixin(__MODULE__), TypeName);
        alias AllTypes = AliasSeq!(TaggedTypesInThisModule, BuiltInTypes);

        switch (type)
        {
            foreach (T; AllTypes)
                case typeName!T:
                    return new Attribute!T(name, type, size);

            default:
                return null;
        }
    }

    import std.meta : AliasSeq, staticIndexOf;
    import std.traits : getUDAs, hasUDA, getSymbolsByUDA;

    alias BuiltInTypes = AliasSeq!(box2i, box2f, int, float, double, m33f, m44f, v2f, v3f, string);
    alias BuiltInTypesNames = AliasSeq!("box2i", "box2f", "int", "float", "double", "m33f", "m44f", "v2f", "v3f", "string");

    template typeName(T)
    {
        static if (staticIndexOf!(T, BuiltInTypes) != -1)
            enum typeName = BuiltInTypesNames[staticIndexOf!(T, BuiltInTypes)];

        else static if (hasUDA!(T, TypeName))
            enum typeName = getUDAs!(T, TypeName)[0].name;

        else
            static assert (0);

    }
}

class Attribute(T) : AttributeBase
{
    T value;

    this(string name, string type, int size)
    {
        this.name = name;
        this.type = type;
        this.size = size;
    }

    override void load(const(ubyte)[] bytes)
    {
        static if (is(T == ChannelList))
        {
            while (bytes.length > 1)
            {
                auto channelName = copyStringz(bytes);
                auto channel = *bytes.read!Channel;
                this.value.channels[channelName] = channel;
            }
        }
        else static if (is(T == string))
        {
            value = copyStringz(bytes);
        }
        else
        {
            value.infuse(bytes);
        }
    }

    override string toString() const
    {
        import std.format : format;
        return "attribute { name: %s, type: %s, size: %s, value: %s }"
            .format(name, type, size, value);
    }
}


