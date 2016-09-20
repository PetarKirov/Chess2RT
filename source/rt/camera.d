module rt.camera;

import rt.importedtypes, rt.ray, rt.sceneloader;

enum Stereo3DOffset : byte
{
    None,
    Left,
    Right,
}

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

    private
    {
        // these internal vectors describe three of the ends of the imaginary
        // ray shooting screen
        Vector upLeft, upRight, downLeft;
        Vector frontDir, rightDir, upDir;
    }

    private void state_invariant() const @safe @nogc pure nothrow
    {
        assert (frameWidth > 0 && frameHeight > 0, "Error: `frameWidth` and `frameHeight` should be > 0");
        assert (aspect.isFinite);
        assert (pos.isFiniteVec);
        assert (yaw.isFinite);
        assert (pitch.isFinite);
        assert (roll.isFinite);
        assert (fov.isFinite);
        assert (focalPlaneDist.isFinite);
        assert (fNumber.isFinite);
        assert (discMultiplier.isFinite);
        assert (stereoSeparation.isFinite);
        assert (upLeft.isFiniteVec);
        assert (upRight.isFiniteVec);
        assert (downLeft.isFiniteVec);
        assert (rightDir.isFiniteVec);
        assert (upDir.isFiniteVec);
        assert (frontDir.isFiniteVec);
    }

    /// Must be called before each frame. Computes the corner variables, needed for getScreenRay()
    void beginFrame() @safe @nogc
    out
    {
        state_invariant();
    }
    body
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
    const @nogc @safe // not pure because of uniform(..) in unitDiscSample(..)
    Ray getScreenRay(double x, double y,
        Stereo3DOffset offset = Stereo3DOffset.None)
    in
    {
        assert (x.isFinite);
        assert (y.isFinite);
        state_invariant();
    }
    out (result)
    {
        assert (result.orig.isFiniteVec);
        assert (result.dir.isFiniteVec);
    }
    body
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

    /// Moves the camera.
    /// Params:
    ///     dx = left/right movement
    ///     dy = up/down movement
    ///     dz = forward/backword movement
    void move(double Δx, double Δy, double Δz)
    in
    {
        enum errMsgArgs = "Error: `Camera.move` called with non-finite floating point args!";

        assert (Δx.isFinite, errMsgArgs);
        assert (Δy.isFinite, errMsgArgs);
        assert (Δz.isFinite, errMsgArgs);

        enum errMsg = "Error: `Camera.move` called on an uninitialized camera. " ~
            "`beginFrame` must be called first.";

        assert (rightDir.isFiniteVec, errMsg);
        assert (upDir.isFiniteVec, errMsg);
        assert (frontDir.isFiniteVec, errMsg);

        state_invariant();
    }
    body
    {
        pos += Δx * rightDir;
        pos += Δy * upDir;
        pos += Δz * frontDir;
    }

    /// Rotates the camera.
    /// Params:
    ///     dYaw = left/right rotation [0..360]
    ///     dRoll = roll rotation [-180..180]
    ///     dPitch = up/down rotation [-90..90]
    void rotate(double ΔYaw, double ΔRoll, double ΔPitch)
    in
    {
        enum errMsg = "Error: `Camera.rotate` called with non-finite floating point args!";

        assert (ΔYaw.isFinite, errMsg);
        assert (ΔRoll.isFinite, errMsg);
        assert (ΔPitch.isFinite, errMsg);

        state_invariant();
    }
    body
    {
        yaw += ΔYaw;
        roll += ΔRoll;
        pitch += ΔPitch;

        pitch = clamp(pitch, -90, 90);
    }

    void setFrameSize(uint width, uint height)
    {
        this.frameWidth = width;
        this.frameHeight = height;
        this.aspect = double(this.frameWidth) / this.frameHeight;
    }

    void deserialize(const SceneDscNode val, SceneLoadContext context)
    {
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

        setFrameSize(context.scene.settings.frameWidth, context.scene.settings.frameHeight);
    }
}

void unitDiscSample(ref double x, ref double y) @safe @nogc // not pure because of uniform(..)
{
    import util.random, std.math;

    // pick a random point in the unit disc with uniform probability by using polar coords.
    // Note the sqrt(). For explanation why it's needed, see
    // http://mathworld.wolfram.com/DiskPointPicking.html
    double angle = uniform(0.0, 1.0) * 2 * std.math.PI;
    double rad = sqrt(uniform(0.0, 1.0));
    x = sin(angle) * rad;
    y = cos(angle) * rad;
}
