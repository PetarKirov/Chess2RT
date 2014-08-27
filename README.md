Chess2RT
========
A variation of chess written in D, using raytracer for rendering.

Performance statistics
----------------------
Available [here](https://github.com/ZombineDev/Chess2RT/blob/master/perf-results.md).

Build Instructions
------------------

You need:
+ git
+ D compiler (e.g. [DMD][1]) with D support level >= DMD _2.065_
+ [DUB][2] package manager version >=_0.9.22-rc.1_
+ [SDL][3] _2.0.3_ binaries

1. Install what's needed (if you haven't yet):
  + **git**
  + **D compiler**
  + **DUB**
  + **SDL2**
    * Linux: PPA packages exist e.g. [here][4]
    * Windows: Download _SDL2-devel-2.0.3-VC.zip_ from [here][3]
2. Git clone: ```git clone https://github.com/ZombineDev/Chess2RT.git```
3. (Windows only) put *SDL2*.dll in the main folder (were the .exe will be produced).
4. Run DUB: ```cd Chess2RT``` & ```dub```

[1]: http://dlang.org/download.html
[2]: http://code.dlang.org/download
[3]: http://www.libsdl.org/download-2.0.php
[4]: https://launchpad.net/~zoogie/+archive/ubuntu/sdl2-snapshots

Scene files
-----------

Scene files are written in JSON and are usually put in the _data/_ folder.

Currently the RTDemo class uses a hardcoded path to _data/lecture4.json_.
