## Systems
1. HP G62 laptop with AMD Athlon II P340 (dual core) CPU, 4GB RAM
  1. Ubuntu 13.10 x64
  2. Windows 8.1 x64

## Results
(_xx_|_y_ T) = compiled in _xx_-bit mode, ran using _y_ number of threads
### Time for lecture4.json
+   2.417ms - (64|1T) with LDC 0.14.0	{dub --build=release --compiler=ldc2} on [system 1.i](#systems)
+   6.004ms - (64|1T) with DMD 2.066.0	{dub} on [system 1.i](#systems)
+  11.739ms - (32|1T) with DMD 2.066.0	{dub} on [system 1.ii](#systems)
+   6.923ms - (32|1T) with DMD 2.066.0	{dub --build=release} on [system 1.ii](#systems)
