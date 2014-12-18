module gui.controls;

import std.variant : Variant;
import derelict.sdl2.types;

import rt.globalsettings;

/// Encapsulates a camera control keys binding.
struct Controls
{
	SDL_Keycode[] keyCodes;
	double dx = 0.0, dy = 0.0, dz = 0.0;
	double dYaw = 0.0, dRoll = 0.0, dPitch = 0.0;

	/// Params:
	/// 	keyCodes =	array of SDL2 key codes to test
	/// 	dx =		left/right movement
	/// 	dy =		up/down movement
	/// 	dz =		forward/backword movement
	/// 	dYaw =		left/right rotation [0..360]
	/// 	dRoll =		roll rotation [-180..180]
	/// 	dPitch =	up/down rotation [-90..90]
	this(SDL_Keycode[] keyCodes, double dx = 0.0, double dy = 0.0, double dz = 0.0,
		 double dYaw = 0.0, double dRoll = 0.0, double dPitch = 0.0)
	{
		this.keyCodes = keyCodes;
		this.dx = dx;
		this.dy = dy;
		this.dz = dz;
		this.dYaw = dYaw;
		this.dRoll = dRoll;
		this.dPitch = dPitch;
	}
}

alias Modifier = void function(GlobalSettings);

Modifier[SDL_Keycode] actions;

void call(SDL_Keycode func, GlobalSettings settings)
{
	auto f = actions[func];
	auto var = Variant(value);
	f(var);
	value = var.get!T;
	return value;
}

static this()
{
	actions = 
	[
		SDLK_p : (GlobalSettings settings) { settings.prepassEnabled = !settings.prepassEnabled; },
		SDLK_f : (GlobalSettings settings) { settings.prepassOnly = !settings.prepassOnly; },
	];
}
