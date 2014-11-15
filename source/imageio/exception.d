module imageio.exception;

class ImageIOException : Exception
{
	@safe pure nothrow 
	this(string msg = "Image error!", Throwable next = null,
	     string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, next, file, line);
	}
}

class UnknownImageTypeException : ImageIOException
{
	@safe pure nothrow 
	this(string msg = "Unknown image type!", Throwable next = null,
	     string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, next, file, line);
	}
}

class ErrorLoadingImageException : ImageIOException
{
	@safe pure nothrow 
	this(string msg = "Error loading image!", Throwable next = null,
	     string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, next, file, line);
	}
}
