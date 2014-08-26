module util.prop;

enum Access
{
	None = 0b00,
	ReadOnly = 0b01,
	WriteOnly = 0b10,
	ReadWrite = 0b11
}

/// Creates a field and get / set methods
mixin template property(T, string propertyName, 
						Access access = Access.ReadWrite)
{
	import std.array;
	import util.enumutils;

	enum typeStr = T.stringof;

	enum field = q{
		private T _propertyName;
	}.replaceFirst("T", typeStr)
	 .replace("propertyName", propertyName);;

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
		}
	}.replaceFirst("T", typeStr)
	 .replace("propertyName", propertyName);

	mixin(field);

	static if (access.hasFlags(Access.ReadOnly))
	{
		mixin(readFunc);	
	}	

	static if (access.hasFlags(Access.WriteOnly))
	{
		mixin(writeFunc);
	}
}