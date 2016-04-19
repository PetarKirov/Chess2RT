module util.array;

//Extremely ugly hack to workaround purity

T[] pure_malloc(T)(size_t count) @nogc nothrow pure
{
    import std.c.stdlib : malloc;
    alias M = void* function(size_t) @nogc nothrow pure;

    void* mem = (cast(M)&malloc)(T.sizeof * count);

    assert (mem);

    return (cast(T*)mem)[0 .. count];
}

void pure_free(void* ptr) @nogc nothrow pure
{
    import std.c.stdlib : free;
    alias F = void function(void*) @nogc nothrow pure;

    (cast(F)&free)(ptr);
}

struct MyArray(T)
{
@trusted pure:
    private T[] storage;
    private size_t elements_count;

    enum defaultInitialCapacity = 16;

    this(size_t initialCapacity) @nogc
    {
        this.reserve(initialCapacity);
    }

    ~this() @nogc
    {
        this.free();
    }

    inout(T[]) opIndex() @nogc inout
    {
        return storage[0 .. elements_count];
    }

    @property size_t length() const
    {
        return this.elements_count;
    }

    void opOpAssign(string op)(T value) @nogc
        if (op == "~")
    {
        if (elements_count >= storage.length)
            reserve(storage.length > 0 ? storage.length * 2 : defaultInitialCapacity);

        storage[elements_count++] = value;
    }

    void reserve(size_t new_capacity) @nogc
    {
        T[] new_storage = pure_malloc!T(new_capacity);
        new_storage[0 .. storage.length] = this.storage[];
        pure_free(this.storage.ptr);
        this.storage = new_storage;
    }

    void free() @nogc
    {
        pure_free(this.storage.ptr);
        this.storage = null;
        this.elements_count = 0;
    }
}

unittest
{
    MyArray!int arr;
    arr.reserve(8);

    assert(arr.storage);
    assert(arr.storage.ptr);
    assert(arr.storage.length == 8);
    assert(arr.length == 0);

    arr ~= 42;
    assert(arr.length == 1);
    assert(arr[][0] == 42);

    foreach (i; 1 .. 11)
        arr ~= i;

    assert(arr.storage.length == 16);
    assert(arr.length == 11);

    auto arrRef = arr[];
    assert(arrRef.length == 11);
    assert(arrRef[0] == 42);
    assert(arrRef[10] == 10);
}

/// Sorts an array using shell sort algorithm. Probably more
/// suited for small arrays.
/// Workarounds the missing @nogc sort function in phobos.
void sort(T)(T[] arr) pure nothrow @nogc @safe
{
    auto inc = arr.length / 2;
    while (inc)
    {
        foreach (ref i, elem; arr)
        {
            while (i >= inc && arr[i - inc] > elem)
            {
                arr[i] = arr[i - inc];
                i -= inc;
            }
            arr[i] = elem;
        }
        inc = (inc == 2) ? 1 : cast(int)(inc * 5.0 / 11);
    }
}
