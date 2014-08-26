module rt.exception;

class RTException : Exception
{
	@safe pure nothrow 
	this(string msg = "Exception in the Raytracer!",
	     string file = __FILE__, size_t line = __LINE__, Throwable next = null)
	{
		super(msg, file, line, next);
	}

}

class NotImplementedException : RTException
{
	@safe pure nothrow 
	this(string msg = "Not implemented feature in the Raytracer!",
	     string file = __FILE__, size_t line = __LINE__, Throwable next = null)
	{
		super(msg, file, line, next);
	}
}

class SceneNotFoundException : RTException
{
	@safe pure nothrow 
	this(string msg = "Scene file not found!",
	     string file = __FILE__, size_t line = __LINE__, Throwable next = null)
	{
		super(msg, file, line, next);
	}
}

class InvalidSceneException : RTException
{
	@safe pure nothrow 
	this(string msg = "Invalid scene file!", Throwable next = null,
		string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line, next);
	}
}