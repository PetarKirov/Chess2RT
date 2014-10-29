module rt.exception;

import std.string;

class RTException : Exception
{
	@safe pure nothrow 
	this(string msg = "Exception in the Raytracer!",
		 Throwable next = null,
	     string file = __FILE__, size_t line = __LINE__)
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
		super(msg, next, file, line);
	}
}

class SceneNotFoundException : RTException
{
	@safe pure nothrow 
	this(string msg = "Scene file not found!",
	     string file = __FILE__, size_t line = __LINE__, Throwable next = null)
	{
		super(msg, next, file, line);
	}
}

class InvalidSceneException : RTException
{
	@safe pure nothrow 
	this(string msg = "Invalid scene file!", Throwable next = null,
		string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, next, file, line);
	}
}

class EntityWithDuplicateName : InvalidSceneException
{
	@safe pure nothrow 
		this(string entityName,
			 string msg = format("An entity named %s is already present!"),			
			 Throwable next = null,
			 string file = __FILE__, size_t line = __LINE__)
		{
			super(msg, next, file, line);
		}
}

class ImageTypeException : RTException
{
	@safe pure nothrow 
	this(string msg = "Image error!", Throwable next = null,
	     string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, next, file, line);
	}
}

class UnknownImageTypeException : ImageTypeException
{
	@safe pure nothrow 
	this(string msg = "Unknown image type!", Throwable next = null,
	     string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, next, file, line);
	}
}

class ErorLoadingImageException : ImageTypeException
{
	@safe pure nothrow 
	this(string msg = "Error loading image!", Throwable next = null,
	     string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, next, file, line);
	}
}
