Chess2RT [![Build Status](https://travis-ci.org/ZombineDev/Chess2RT.svg?branch=master)](https://travis-ci.org/ZombineDev/Chess2RT)
========
A raytracer renderer, written in D, which will eventually be used for a
3d rendered chess game (and/or a variation of it).

What works
----------
+ Simple geometry objects: spheres, cubes and a horizontal plane.
+ CSG combinations of supported geometry  objects (including CSG objects).
+ Procedural textures.
+ Lambert and Phong shading.
+ Loading scenes from .sdl or .json files. You can see sample scene files in _data/_.
+ Interactive camera movement (←↑→↓ for movement, Shift+←↓→↓ for mouse look,
Ctrl+←→ for rotation and Ctrl+↑↓ for up and down moving).

Performance statistics
----------------------
Available [here](https://github.com/ZombineDev/Chess2RT/blob/master/perf-results.md).

Build Instructions
------------------
You need:
+ git to be in $PATH (dub needs it)
+ D compiler (e.g. [DMD][1]) with D support level >= DMD *v2.066.1*
+ [DUB][2] package manager *v0.9.22*, or newer
+ [SDL][3] _2.0.3_ binaries (included for windows)

1. Install what's needed (if you haven't yet)
  + **D compiler**
  + **DUB**
  + **SDL2**
    * Linux: PPA packages exist e.g. [here][4]
    * Windows: Use libsdl from the /lib folder or download _SDL2-devel-2.0.3-VC.zip_ from [here][3]

2. Git clone:
```git clone https://github.com/ZombineDev/Chess2RT.git```

3. (Windows only) put *SDL2*.dll in the corresponding bin/ folder (were the .exe will be produced).

4. Run DUB:

```
cd Chess2RT
dub
```

Scene files
-----------
Scene files are written in [SDLang][5] or JSON and are usually put in the `data/` folder.
To render a specific scene you can either:
+ call the app from the command-line like this:
```chess2rt --file=data/scene1.sdl```
+ place the path to scene you wish to load in *data/default_scene.path* and call chess2rt without arguments.

Acknowledgement
---------------
I developed this project for the 3D Graphics and Raytracing course at fmi.uni-sofia.
Most of the code in `./source/rt/` is based on https://github.com/anrieff/trinity/.

This project uses [SDL 2.03](https://www.libsdl.org). Windows x86 and x86_64 binaries
are included in the corresponding /lib/[Win32 or Win64] folders.

[1]: http://dlang.org/download.html
[2]: http://code.dlang.org/download
[3]: http://www.libsdl.org/download-2.0.php
[4]: https://launchpad.net/~zoogie/+archive/ubuntu/sdl2-snapshots
[5]: http://sdl.ikayzo.org/
