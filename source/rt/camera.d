module rt.camera;

import rt.importedtypes, rt.sceneloader, rt.globalsettings;

enum Stereo3DOffset : byte
{
	None,
	Left,
	Right,
};

class Camera : Deserializable
{
	this() { }

	this(size_t frameWidth, size_t frameHeight, double fov, 
		Vector pos, double yaw, double pitch, double roll, )
	{
		this.pos = pos;
		this.yaw = yaw;
		this.pitch = pitch;
		this.roll = roll;
		this.fov = fov;
		this.aspect = aspect;
	}

	size_t frameWidth;
	size_t frameHeight;
	double aspect = 1.0; //!< The aspect ratio of the camera frame. Should usually be frameWidth/frameHeight,

	Vector pos; //!< position of the camera in 3D.

	double yaw = 0; //!< Yaw angle in degrees (rot. around the Y axis, meaningful values: [0..360])
	double pitch = 0.0; //!< Pitch angle in degrees (rot. around the X axis, meaningful values: [-90..90])
	double roll = 0.0; //!< Roll angle in degrees (rot. around the Z axis, meaningful values: [-180..180])

	double fov = 0.0; //!< The Field of view in degrees (meaningful values: [3..160])
	double focalPlaneDist = 1.0;
	double fNumber = 1.0;
	double discMultiplier;
	bool dof = false; // on or off
	size_t numSamples = 25;
	double stereoSeparation = 0.0;

	/// Must be called before each frame. Computes the corner variables, needed for getScreenRay()
	void beginFrame()
	{
		double x = -aspect;
		double y = +1;

		Vector corner = Vector(x, y, 1);
		Vector center = Vector(0, 0, 1);
		
		double lenXY = (corner - center).length();
		double wantedLength = tan(radians(fov / 2));
		
		double scaling = wantedLength / lenXY;
		
		x *= scaling;
		y *= scaling;
		
		this.upLeft = Vector(x, y, 1);
		this.upRight = Vector(-x, y, 1);
		this.downLeft = Vector(x, -y, 1);
		
		Matrix rotation = Matrix.rotateZ(radians(roll))
						* Matrix.rotateX(radians(pitch))
						* Matrix.rotateY(radians(yaw));

		upLeft = mul(upLeft, rotation);
		upRight = mul(upRight, rotation);
		downLeft = mul(downLeft, rotation);

		rightDir = mul(Vector(1, 0, 0), rotation);
		upDir    = mul(Vector(0, 1, 0), rotation);
		frontDir = mul(Vector(0, 0, 1), rotation);
		
		upLeft += pos;
		upRight += pos;
		downLeft += pos;
	}

	/// generates a screen ray through a pixel (x, y - screen coordinates, not necessarily integer).
	/// if the camera parameter is present - offset the rays' start to the left or to the right,
	/// for use in stereoscopic rendering
	Ray getScreenRay(double x, double y, Stereo3DOffset offset = Stereo3DOffset.None) const
	{
		Ray result; // A, B -     C = A + (B - A) * x
		result.orig = this.pos;
		Vector target = upLeft +
			(upRight - upLeft) * (x / cast(double)frameWidth) +
			(downLeft - upLeft) * (y / cast(double)frameHeight);
		
		// A - camera; B = target
		result.dir = target - this.pos;

		result.dir.normalize();
		
		if (offset != Stereo3DOffset.None) {
			// offset left/right for stereoscopic rendering
			result.orig += rightDir * (offset == Stereo3DOffset.Right ? +stereoSeparation : -stereoSeparation);
		}
		
		if (!dof) return result;
		
		double cosTheta = dot(result.dir, frontDir);
		double M = focalPlaneDist / cosTheta;
		
		Vector T = result.orig + result.dir * M;

		double dx, dy;
		unitDiscSample(dx, dy);
		
		dx *= discMultiplier;
		dy *= discMultiplier;
		
		result.orig = this.pos + dx * rightDir + dy * upDir;
		if (offset != Stereo3DOffset.None) {
			result.orig += rightDir * (offset == Stereo3DOffset.Right ? +stereoSeparation : -stereoSeparation);
		}
		result.dir = (T - result.orig);
		result.dir.normalize();
		return result;
	}

	void move(double dx, double dz)
	{
		pos += dx * rightDir;
		pos += dz * frontDir;
	}
	void rotate(double dx, double dz)
	{
		pitch += dz;
		if (pitch >  90) pitch = 90;
		if (pitch < -90) pitch = -90;
		
		yaw += dx;
	}

	void deserialize(Value val, SceneLoadContext context)
	{
		this.frameWidth = context.scene.settings.frameWidth;
		this.frameHeight = context.scene.settings.frameHeight;
		this.aspect = cast(double)this.frameWidth / this.frameHeight;

		context.set(this.pos, val, "pos");

		context.set(this.yaw, val, "yaw");
		context.set(this.pitch, val, "pitch");
		context.set(this.roll, val, "roll");

		context.set(this.fov, val, "fov");
		context.set(this.focalPlaneDist, val, "focalPlaneDist");
		context.set(this.fNumber, val, "fNumber");
		context.set(this.dof, val, "dof");
		context.set(this.numSamples, val, "numSamples");
		context.set(this.stereoSeparation, val, "stereoSeparation");
		discMultiplier = 10.0 / fNumber;
	}

private:
	// these internal vectors describe three of the ends of the imaginary
	// ray shooting screen
	Vector upLeft, upRight, downLeft;

	Vector frontDir, rightDir, upDir;
}

void unitDiscSample(ref double x, ref double y)
{
	import std.random, std.math;
	
	// pick a random point in the unit disc with uniform probability by using polar coords.
	// Note the sqrt(). For explanation why it's needed, see 
	// http://mathworld.wolfram.com/DiskPointPicking.html
	double angle = uniform(0.0, 1.0) * 2 * std.math.PI;
	double rad = sqrt(uniform(0.0, 1.0));
	x = sin(angle) * rad;
	y = cos(angle) * rad;
}
