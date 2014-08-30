## Systems
1. HP G62 laptop with AMD Athlon II P340 (dual core) CPU, 4GB RAM
  1. Ubuntu 13.10 x64
  2. Windows 8.1 x64

## Versions
- [v0.1.0][1]

## Results
- Time is in seconds
- Arch - e.g. compiled for x86 or x86_64
- TC - max Thread Count allowed

### Results for lecture4.json

| Id | Time    | Version | Arch | TC | System     | Compiler    | Build Command                             |
|---:|--------:|:-------:|:----:|:--:|------------|-------------|-------------------------------------------|
| 1  | 2.417   | v0.1.0  | 64   | 1  | system 1.1 | LDC 0.14.0  | ```dub --build=release --compiler=ldc2``` |
| 2  | 6.004   | v0.1.0  | 64   | 1  | system 1.1 | DMD 2.066.0 | ```dub```                                 |
| 3  | 11.739  | v0.1.0  | 32   | 1  | system 1.2 | DMD 2.066.0 | ```dub```                                 |
| 4  | 6.923   | v0.1.0  | 32   | 1  | system 1.2 | DMD 2.066.0 | ```dub --build=release```                 |


[1]: https://github.com/ZombineDev/Chess2RT/commit/53d31bd25aed945793689c486c9ceb8e998720db
