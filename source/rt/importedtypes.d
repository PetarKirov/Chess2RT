module rt.importedtypes;

public import std.math;
public import gfm.math.funcs;

import gfm.math.vector;
import gfm.math.shapes;
import gfm.math.matrix;

alias Vector = gfm.math.vector.vec3d;
alias Matrix = gfm.math.matrix.mat3d;
alias Ray = gfm.math.shapes.Ray!(double, 3);