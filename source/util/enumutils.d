module util.enumutils;

bool hasFlags(E)(E enumValue, E[] flags...)
	if (is(E == enum))
{
	foreach (flag; flags)
	{
		if ((enumValue & flag) == 0)
			return false;
	}

	return true;
}