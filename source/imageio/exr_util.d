module imageio.exr_util;

import gfm.math : vec2f, vec3f, mat4f;

import imageio.exr;

vec3f computeYw (in ref Chromaticities cr)
{
	mat4f m = RGBtoXYZ(cr, 1);
	return vec3f(m.c[0][1], m.c[1][1],
		m.c[2][1]) / (m.c[0][1] + m.c[1][1] + m.c[2][1]);
}

mat4f RGBtoXYZ (const Chromaticities chroma, float Y)
{
    // For an explanation of how the color conversion matrix is derived,
    // see Roy Hall, "Illumination and Color in Computer Generated Imagery",
    // Springer-Verlag, 1989, chapter 3, "Perceptual Response"; and
    // Charles A. Poynton, "A Technical Introduction to Digital Video",
    // John Wiley & Sons, 1996, chapter 7, "Color science for video".
    //

    // X and Z values of RGB value (1, 1, 1), or "white"

    float X = chroma.white.x * Y / chroma.white.y;
    float Z = (1 - chroma.white.x - chroma.white.y) * Y / chroma.white.y;

    // Scale factors for matrix rows
    float d = chroma.red.x   * (chroma.blue.y  - chroma.green.y) +
	      chroma.blue.x  * (chroma.green.y - chroma.red.y) +
	      chroma.green.x * (chroma.red.y   - chroma.blue.y);

    float Sr = (X * (chroma.blue.y - chroma.green.y) -
	        chroma.green.x * (Y * (chroma.blue.y - 1) +
		chroma.blue.y  * (X + Z)) +
		chroma.blue.x  * (Y * (chroma.green.y - 1) +
		chroma.green.y * (X + Z))) / d;

    float Sg = (X * (chroma.red.y - chroma.blue.y) +
		chroma.red.x   * (Y * (chroma.blue.y - 1) +
		chroma.blue.y  * (X + Z)) -
		chroma.blue.x  * (Y * (chroma.red.y - 1) +
		chroma.red.y   * (X + Z))) / d;

    float Sb = (X * (chroma.green.y - chroma.red.y) -
		chroma.red.x   * (Y * (chroma.green.y - 1) +
		chroma.green.y * (X + Z)) +
		chroma.green.x * (Y * (chroma.red.y - 1) +
		chroma.red.y   * (X + Z))) / d;

    // Assemble the matrix
    mat4f m;

    m.c[0][0] = Sr * chroma.red.x;
    m.c[0][1] = Sr * chroma.red.y;
    m.c[0][2] = Sr * (1 - chroma.red.x - chroma.red.y);

    m.c[1][0] = Sg * chroma.green.x;
    m.c[1][1] = Sg * chroma.green.y;
    m.c[1][2] = Sg * (1 - chroma.green.x - chroma.green.y);

    m.c[2][0] = Sb * chroma.blue.x;
    m.c[2][1] = Sb * chroma.blue.y;
    m.c[2][2] = Sb * (1 - chroma.blue.x - chroma.blue.y);

    return m;
}
