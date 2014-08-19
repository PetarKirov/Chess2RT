module rt.camera;

import std.json;
import rt.importedtypes, rt.sceneloader;


enum Stereo3DOffset : byte
{
	None,
	Left,
	Right,
};

class Camera : JsonDeserializer
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

	Vector pos; //!< position of the camera in 3D.
	double yaw; //!< Yaw angle in degrees (rot. around the Y axis, meaningful values: [0..360])
	double pitch; //!< Pitch angle in degrees (rot. around the X axis, meaningful values: [-90..90])
	double roll; //!< Roll angle in degrees (rot. around the Z axis, meaningful values: [-180..180])
	double fov; //!< The Field of view in degrees (meaningful values: [3..160])
	double aspect; //!< The aspect ratio of the camera frame. Should usually be frameWidth/frameHeight,
	double focalPlaneDist;
	double fNumber;
	bool dof; // on or off
	int numSamples;
	double discMultiplier;
	double stereoSeparation;
	
	size_t frameWidth;
	size_t frameHeight;

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

		upLeft = rotation * upLeft;
		upRight = rotation * upRight;
		downLeft = rotation * downLeft;

		rightDir = rotation * Vector(1, 0, 0);
		upDir    = rotation * Vector(0, 1, 0);
		frontDir = rotation * Vector(0, 0, 1);
		
		upLeft += pos;
		upRight += pos;
		downLeft += pos;
	}

	/// generates a screen ray through a pixel (x, y - screen coordinates, not necessarily integer).
	/// if the camera parameter is present - offset the rays' start to the left or to the right,
	/// for use in stereoscopic rendering
	Ray getScreenRay(double x, double y, Stereo3DOffset offset = Stereo3DOffset.None)
	{
		Ray result; // A, B -     C = A + (B - A) * x
		result.orig = this.pos;
		Vector target = upLeft +
			(upRight - upLeft) * (x / double(frameWidth)) +
			(downLeft - upLeft) * (y / double(frameHeight));
		
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

	void loadFromJson(JSONValue json, SceneLoadContext context)
	{
		context.set(this.pos, json, "pos");
		this.aspect = cast(double)this.frameWidth / this.frameHeight;	
		context.set(this.yaw, json, "yaw");
		context.set(this.pitch, json, "pitch");
		context.set(this.roll, json, "roll");
		context.set(this.fov, json, "fov");
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
