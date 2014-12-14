module util.array;

//Extremely ugly hack to workaround purity
void my_free_impl(void* ptr) @nogc nothrow
{
	import std.c.stdlib : free;
	free(ptr);
}

void my_free(void* ptr) @nogc nothrow pure
{
	alias F = void function(void*) @nogc nothrow pure;
	(cast(F)&my_free_impl)(ptr);
}

void* my_malloc_impl(size_t size) @nogc nothrow
{
	import std.c.stdlib : malloc;
	return malloc(size);
}

void* my_malloc(size_t size) @nogc nothrow pure
{
	alias M = void* function(size_t) @nogc nothrow pure;
	return (cast(M)&my_malloc_impl)(size);
}

struct MyArray(T)
{
@trusted pure:
	private T[] data;
	private size_t length_;

	enum defaultInitialCapacity = 16;

	this(size_t initialCapacity) @nogc
	{
		this.reserve(initialCapacity);
	}

	~this() @nogc
	{
		free();
	}

	@property size_t length() const
	{
		return this.length_;
	}
	
	void opOpAssign(string op)(T value) @nogc
		if (op == "~")
	{
		if (length >= data.length)
			reserve(data.length == 0 ?
			        defaultInitialCapacity :
			        data.length * 2);
		
		data[length_++] = value;
	}
	
	void reserve(size_t newCapacity) @nogc
	{
		auto newData = my_malloc(T.sizeof * newCapacity);
		assert(newData);
		T[] newArr = (cast(T*)newData)[0 .. newCapacity];

		newArr[0 .. data.length] = data[];
		my_free(data.ptr);
		data = newArr;
	}

	void free() @nogc
	{
		my_free(data.ptr);
		data = null;
		length_ = 0;
	}

	inout(T[]) opIndex() @nogc inout
	{
		return data[0 .. length];
	}
}

unittest
{
	MyArray!int arr;
	arr.reserve(8);

	assert(arr.data);
	assert(arr.data.ptr);
	assert(arr.data.length == 8);
	assert(arr.length == 0);

	arr ~= 42;
	assert(arr.length == 1);
	assert(arr[][0] == 42);

	foreach (i; 1 .. 11)
		arr ~= i;

	assert(arr.data.length == 16);
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
