module util.counter;

mixin template callCounter(alias func)
{
	static size_t callsCount;
}