module util.array;

struct MyArray(T)
{
	T[] data;
	size_t length;
	size_t capacity;
	
	void opOpAssign(string op)(T value) @nogc if (op == "~")
	{
		if (length >= capacity)
			reserve(capacity == 0? 16 : capacity * 2);
		
		data[length++] = value;
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
	
	void reserve(size_t newSize) @nogc
	{
		import std.c.stdlib : malloc, free;
		
		if (data is null)
		{
			length = 0;
			capacity = 0;
		}
		
		T* newArr = cast(T*)malloc(T.sizeof * newSize);
		
		foreach (i; 0 .. length)
			newArr[i] = data[i];
		
		capacity = newSize;
		free(data.ptr);
		data = newArr[0 .. capacity];
	}
	
	~this()
	{
		import std.c.stdlib : free;
		free(data.ptr);
		data = null;
		length = 0;
		capacity = 0;
	}
	
	inout(T)[] opIndex() @nogc inout
	{
		return data;
	}
}

