module rt.renderer;

import std.random;
import ae.utils.graphics.image, gfm.math.box;
import rt.scene, rt.color, rt.importedtypes, rt.intersectable, rt.node, rt.camera, rt.ray, rt.light;

void renderRT(Image!Color outputImage, Scene scene)
{
	int W = scene.settings.frameWidth;
	int H = scene.settings.frameHeight;
	
	auto buckets = getBucketsList(scene);

	if (scene.settings.wantPrepass || scene.settings.gi)
	{
		// We render the whole screen in three passes.
		// 1) First pass - use very coarse resolution rendering, tracing a single ray for a 16x16 block:
		foreach(r; buckets)
		{
			for (int dy = 0; dy < r.height; dy += 16)
			{
				int ey = min(r.height, dy + 16);

				for (int dx = 0; dx < r.width; dx += 16)
				{
					int ex = min(r.width, dx + 16);

					Color c = renderPixelNoAA(outputImage, scene, r.min.x + dx, r.min.y + dy, ex - dx, ey - dy);

					//if (!drawRect(box2i(r.x0 + dx, r.y0 + dy, r.min.x + ex, r.y0 + ey), c))
					//	return;
				}
			}
		}
	}

	import rt.exception;
	//throw new NotImplementedException();
}

box2i[] getBucketsList(Scene scene)
{
	const int BUCKET_SIZE = 48;
	int W = scene.settings.frameWidth;
	int H = scene.settings.frameHeight;
	int BW = (W - 1) / BUCKET_SIZE + 1;
	int BH = (H - 1) / BUCKET_SIZE + 1;
	
	box2i[] res;
	
	for (int y = 0; y < BH; y++) {
		if (y % 2 == 0)
			for (int x = 0; x < BW; x++)
				res ~= box2i(x * BUCKET_SIZE, y * BUCKET_SIZE, (x + 1) * BUCKET_SIZE, (y + 1) * BUCKET_SIZE);
		else
			for (int x = BW - 1; x >= 0; x--)
				res ~= box2i(x * BUCKET_SIZE, y * BUCKET_SIZE, (x + 1) * BUCKET_SIZE, (y + 1) * BUCKET_SIZE);
	}
	
	foreach (bucket; res)
		bucket.clip(W, H);
	
	return res;
}

/// Gets the color for a single pixel, without antialiasing
Color renderPixelNoAA(Image!Color outputImage, Scene scene, int x, int y, int dx = 1, int dy = 1)
{
	outputImage[x, y] = renderSample(scene, x, y, dx, dy);
	return outputImage[x, y];
}

// trace a ray through pixel coords (x, y).
Color renderSample(Scene scene, double x, double y, int dx = 1, int dy = 1)
{
	if (scene.camera.dof)
	{
		return renderSampleDof(scene, x, y, dx, dy);
	}
	else if (scene.settings.gi)
	{
		return renderSampleGI(scene, x, y, dx, dy);
	}
	else
	{
		return renderSampleDefault(scene, x, y, dx, dy);
	}
}

Color renderSampleDof(Scene scene, double x, double y, int dx = 1, int dy = 1)
{
	auto average = Color(0, 0, 0);
	
	for (int i = 0; i < scene.camera.numSamples; i++)
	{
		if (scene.camera.stereoSeparation == 0) // stereoscopic rendering?
			average += raytrace(scene, scene.camera.getScreenRay(x + uniform(0.0, 1.0) * dx, y +uniform(0.0, 1.0) * dy));
		else
		{
			average += Color.combineStereo(
				raytrace(scene, scene.camera.getScreenRay(x + uniform(0.0, 1.0) * dx, y + uniform(0.0, 1.0) * dy, Stereo3DOffset.Left)),
				raytrace(scene, scene.camera.getScreenRay(x + uniform(0.0, 1.0) * dx, y + uniform(0.0, 1.0) * dy, Stereo3DOffset.Right))
				);
		}
	}
	return average / scene.camera.numSamples;
}

Color renderSampleGI(Scene scene, double x, double y, int dx = 1, int dy = 1)
{
	auto average = Color(0, 0, 0);
	
	for (int i = 0; i < scene.settings.numPaths; i++)
	{
		average += pathtrace(scene,
			scene.camera.getScreenRay(x + uniform(0.0, 1.0) * dx, y + uniform(0.0, 1.0) * dy),
			Color(1, 1, 1));
	}
	return average / scene.settings.numPaths;
}

Color renderSampleDefault(Scene scene, double x, double y, int dx = 1, int dy = 1)
{
	if (scene.camera.stereoSeparation == 0)
		return raytrace(scene, scene.camera.getScreenRay(x, y));
	else				
		return Color.combineStereo( // trace one ray through the left camera and one ray through the right, then combine the results
		                     raytrace(scene, scene.camera.getScreenRay(x, y, Stereo3DOffset.Left)),
		                     raytrace(scene, scene.camera.getScreenRay(x, y, Stereo3DOffset.Right)));
}

Color raytrace(Scene scene, const Ray ray)
{
	return trace(scene, ray, TraceType.Ray);
}

Color pathtrace(Scene scene, const Ray ray, const Color pathMultiplier)
{
	return trace(scene, ray, TraceType.Path);
}

enum TraceType
{
	Ray,
	Path
}

struct TraceResult
{
	Ray ray;
	IntersectionData data;
	Node closestNode;
	bool hitLight;
	Color hitLightColor;
}

Color trace(Scene scene, const Ray ray, TraceType traceType)
{
	TraceResult result;
	result.ray = ray;
	
	if (ray.depth > scene.settings.maxTraceDepth)
		return Color(0, 0, 0);

	//	if (ray.flags & RF_DEBUG)
	//		cout << "  Raytrace[start = " << ray.start << ", dir = " << ray.dir << "]\n";

	result.data.dist = 1e99;
	
	// find closest intersection point:
	foreach (node; scene.nodes)
		if (node.intersect(ray, result.data))
			result.closestNode = node;
	
	// check if the closest intersection point is actually a light:
	foreach (light; scene.lights)
		if (light.intersect(ray, result.data))
		{
			result.hitLight = true;
			result.hitLightColor = light.color();
		}

	final switch(traceType)
	{
		case TraceType.Ray:
			return raytrace(scene, result);
		case TraceType.Path:
			return pathtrace(scene, result, Color(1, 1, 1));
	}
}

/// traces a ray in the scene and returns the visible light that comes from that direction
Color raytrace(Scene scene, TraceResult result)
{
	if (result.hitLight)
		return result.hitLightColor;

	// no intersection? use the environment, if present:
	if (!result.closestNode)
		return scene.environment.getEnvironment(result.ray.dir);
	
//	if (ray.flags & RF_DEBUG) {
//		cout << "    Hit " << closestNode->geom->getName() << " at distance " << fixed << setprecision(2) << data.dist << endl;
//		cout << "      Intersection point: " << data.p << endl;
//		cout << "      Normal:             " << data.normal << endl;
//		cout << "      UV coods:           " << data.u << ", " << data.v << endl;
//	}

	// if the node we hit has a bump map, apply it here:
	if (result.closestNode.bumpmap)
		result.closestNode.bumpmap.modifyNormal(result.data);
	
	// use the shader of the closest node to shade the intersection:
	return result.closestNode.shader.shade(result.ray, result.data);
}


Color pathtrace(Scene scene, TraceResult result, const Color pathMultiplier)
{
	if (result.hitLight)
	{
		/*
		 * if the ray actually hit a light, check if we need to pass this light back along the path.
		 * If the last surface along the path was a diffuse one (Lambert/Phong), we need to discard the
		 * light contribution, since for diffuse material we do explicit light sampling too, thus the
		 * light would be over-represented and the image a bit too bright. We may discard light checks
		 * for secondary rays altogether, but we would lose caustics and light reflections that way.
		 */
		if (result.ray.flags & RayFlags.RF_DIFFUSE)
			return Color(0, 0, 0);
		else
			return result.hitLightColor * pathMultiplier;
	}

	// no intersection? use the environment, if present:
	if (!result.closestNode)
		return scene.environment.getEnvironment(result.ray.dir) * pathMultiplier;
	
	auto resultDirect = Color(0, 0, 0);
	
	// We continue building the path in two ways:
	// 1) (a.k.a. "direct illumination"): connect the current path end to a random light.
	//    This approximates the direct lighting towards the intersection point.
	if (scene.lights.length)
	{
		// choose a random light:
		int lightIndex = uniform(0, scene.lights.length);
		Light light = scene.lights[lightIndex];
		int numLightSamples = light.getNumSamples();
		
		// choose a random sample of that light:
		int lightSampleIdx = uniform(0, numLightSamples);
		
		// sample the light and see if it came out nonzero:
		Vector pointOnLight;
		Color lightColor;
		light.getNthSample(lightSampleIdx, result.data.p, pointOnLight, lightColor);

		if (lightColor.intensity() > 0 && scene.testVisibility(result.data.p + result.data.normal * 1e-6, pointOnLight))
		{
			// w_out - the outgoing ray in the BRDF evaluation
			Ray w_out;
			w_out.orig = result.data.p + result.data.normal * 1e-6;
			w_out.dir = pointOnLight - w_out.orig;
			w_out.dir.normalize();
			//
			// calculate the light contribution in a manner, consistent with classic path tracing:
			float solidAngle = light.solidAngle(w_out.orig); // solid angle of the light, as seen from x.
			// evaluate the BRDF:
			Color brdfAtPoint = result.closestNode.shader.eval(result.data, result.ray, w_out); 
			
			lightColor = light.color() * solidAngle / (2*PI);
			
			// the probability to choose a particular light among all lights: 1/N
			float pdfChooseLight = 1.0f / scene.lights.length;
			// the probability to shoot a ray in a random direction: 1/2*pi
			float pdfInLight = 1 / (2*PI);
			
			// combined probability for that ray:
			float pdf = pdfChooseLight * pdfInLight;
			
			if (brdfAtPoint.intensity() > 0)
				// Kajia's rendering equation, evaluated at a single incoming/outgoing directions pair:
				/* Li */    /*BRDFs@path*/    /*BRDF*/   /*ray probability*/
				resultDirect = lightColor * pathMultiplier * brdfAtPoint / pdf; 
		}
	}
	
	// 2) (a.k.a. "indirect illumination"): continue the path randomly, by asking the
	//    BRDF to choose a continuation direction
	Ray w_out;
	Color brdfEval; // brdf at the chosen direction
	float pdf; // the probability to choose that specific newRay
	// sample the BRDF:
	result.closestNode.shader.spawnRay(result.data, result.ray, w_out, brdfEval, pdf);
	
	if (pdf < 0) return Color(1, 0, 0);  // bogus BRDF; mark in red
	if (pdf == 0) return Color(0, 0, 0);  // terminate the path, as required
	Color resultGi;
	resultGi = pathtrace(scene, w_out, pathMultiplier * brdfEval / pdf); // continue the path normally; accumulate the new term to the BRDF product
	
	return resultDirect + resultGi;
}