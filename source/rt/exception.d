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
    @safe pure
    this(string entityName,
         string file = __FILE__, size_t line = __LINE__)
    {
        msg = format("An entity named %s is already present!", entityName);
        super(msg, next, file, line);
    }
}

class PropertyNotSpecifiedException : InvalidSceneException
{
    @safe pure
    this(string propertyName,
         string msg = null,
         Throwable next = null,
         string file = __FILE__, size_t line = __LINE__)
    {
        msg = msg? msg : format("The required property '%s' is not specified!", propertyName);
        super(msg, next, file, line);
    }
}
