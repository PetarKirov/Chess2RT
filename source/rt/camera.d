module rt.camera;

import rt.importedtypes;

class Camera
{
	this(size_t frameWidth, size_t frameHeight, double fov, 
		Vector pos, double yaw, double pitch, double roll, )
	{
		this.pos = pos;
		this.yaw = yaw;
		this.pitch = pitch;
		this.roll = roll;
		this.fov = frameWidth / frameHeight;
		this.aspect = aspect;
	}

	Vector pos; //!< position of the camera in 3D.
	double yaw; //!< Yaw angle in degrees (rot. around the Y axis, meaningful values: [0..360])
	double pitch; //!< Pitch angle in degrees (rot. around the X axis, meaningful values: [-90..90])
	double roll; //!< Roll angle in degrees (rot. around the Z axis, meaningful values: [-180..180])
	double fov; //!< The Field of view in degrees (meaningful values: [3..160])
	double aspect; //!< The aspect ratio of the camera frame. Should usually be frameWidth/frameHeight,
	
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
		
		upLeft += pos;
		upRight += pos;
		downLeft += pos;
	}
	
	/// generates a screen ray through a pixel (x, y - screen coordinates, not necessarily integer).
	Ray getScreenRay(double x, double y)
	{
		Ray result; // A, B -     C = A + (B - A) * x
		result.orig = this.pos;
		Vector target = upLeft +
			(upRight - upLeft) * (x / cast(double)frameWidth) +
				(downLeft - upLeft) * (y / cast(double)frameHeight);
		
		// A - camera; B = target
		result.dir = target - this.pos;
		
		result.dir.normalize();
		
		return result;
	}

private:
	// these internal vectors describe three of the ends of the imaginary
	// ray shooting screen
	Vector upLeft, upRight, downLeft;
}
