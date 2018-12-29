module util.array;

struct MyArray(T)
{
    private T[] storage;
    private size_t elements_count;

    enum defaultInitialCapacity = 16;

    private void freeMem()
    {
        import std.experimental.allocator.mallocator;

        Mallocator.instance.deallocate(cast(void[])this.storage);

        this.storage = null;
        this.elements_count = 0;
    }

    private void reserve(size_t new_capacity)
    {
        import std.experimental.allocator;
        import std.experimental.allocator.mallocator;

        if (!this.storage.ptr || !this.storage.length)
            this.storage = cast(T[])Mallocator.instance.allocate(new_capacity * T.sizeof);
        else
            Mallocator.instance.expandArray(this.storage, new_capacity - this.storage.length);
    }

    @trusted @nogc pure nothrow:

    this(size_t initialCapacity)
    {
        auto reserveMem = assumePureNothrowNogc(&this.reserve);
        reserveMem(initialCapacity);
    }

    ~this()
    {
        assumePureNothrowNogc(&this.freeMem)();
    }

    inout(T[]) opIndex() inout
    {
        return storage[0 .. elements_count];
    }

    @property size_t length() const
    {
        return this.elements_count;
    }

    void opOpAssign(string op)(in T value)
        if (op == "~")
    {
        auto reserveMem = assumePureNothrowNogc(&this.reserve);

        if (elements_count >= storage.length)
            reserveMem(storage.length > 0 ? storage.length * 2 : defaultInitialCapacity);

        storage[elements_count++] = value;
    }
}

@safe @nogc pure nothrow
unittest
{
    auto arr = MyArray!int(8);

    assert(arr.storage);
    assert(arr.storage.ptr !is null);
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

//Extremely ugly hack to workaround purity

auto assumePureNothrowNogc(T)(T t) @nogc nothrow pure @system
{
    import std.traits;

    static assert (isFunctionPointer!T || isDelegate!T);

    enum attrs = functionAttributes!T | FunctionAttribute.pure_ | FunctionAttribute.nogc | FunctionAttribute.nothrow_;

    return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}
