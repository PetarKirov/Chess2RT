module util.array;

struct MyArray(T)
{
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

	int opApply(int delegate(ref T) @nogc dg) @nogc
	{
		int result = 0;
		
		foreach (ref elem; data)
		{
			result = dg(elem);
			if (result)
				break;
		}

		return result;
	}
	
	void reserve(size_t newCapacity) @nogc
	{
		import std.c.stdlib : malloc, free;

		auto newData = malloc(T.sizeof * newCapacity);
		assert(newData);
		T[] newArr = (cast(T*)newData)[0 .. newCapacity];

		newArr[0 .. data.length] = data[];
		free(data.ptr);
		data = newArr;
	}

	void free() @nogc
	{
		import std.c.stdlib : free;
		free(data.ptr);
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