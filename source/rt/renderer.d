﻿module rt.renderer;

import std.random;
import ae.utils.graphics.image, gfm.math.box;
import rt.scene, rt.color, rt.importedtypes, rt.intersectable, rt.node, rt.camera, rt.ray, rt.light;

package enum TraceType
{
	Ray,
	Path
}

package struct TraceResult
{
	Ray ray;
	IntersectionData data;
	Node closestNode;
	bool hitLight;
	Color hitLightColor;
}

class Renderer
{
	const Scene scene;
	Image!Color outputImage;
	Image!bool needsAA;

	this(const Scene scene, Image!Color output)
	{
		this.scene = scene;
		this.outputImage = output;
		this.needsAA.size(outputImage.w, outputImage.h);
	}

	void renderRT()
	{	
		auto buckets = getBucketsList(scene.settings.frameWidth, scene.settings.frameHeight);

		uint W = scene.settings.frameWidth;
		uint H = scene.settings.frameHeight;

		// We render the whole screen in three passes.

		// 1) First pass - use very coarse resolution rendering,
		// tracing a single ray for a 16x16 block:
		if (scene.settings.prepassEnabled || scene.settings.GIEnabled)			
			foreach(r; buckets)
			{
				for (int dy = 0; dy < r.height; dy += 16)
				{
					int ey = min(r.height, dy + 16);

					for (int dx = 0; dx < r.width; dx += 16)
					{
						int ex = min(r.width, dx + 16);

						Color c = renderPixelNoAA(r.min.x + dx, r.min.y + dy, ex - dx, ey - dy);

						//if (!drawRect(box2i(r.min.x + dx, r.min.y + dy, r.min.x + ex, r.min.y + ey), c))
						//    return;
					}
				}
			}
		

		// 2) Second pass - shoot _one_ ray per pixel:
		foreach (b; buckets)
		{
			foreach (y; b.min.y .. b.max.y)
				foreach (x; b.min.x .. b.max.x)
					renderPixelNoAA(x, y);
			// TODO(check if correct): if (!scene.settings.interactive && !displayVFBRect(r, vfb)) return;
		}

		// 3) Third pass - find pixels that need AA (which
		// are too different than their neighbours)
		// and shoot additional rays per pixel.
		if (!scene.settings.AAEnabled)
			return;

		foreach (y; 0 .. H) {
			foreach (x; 0 .. W)
			{
				Color[5] neighs;
				neighs[0] = outputImage[x, y];

				neighs[1] = outputImage[x     > 0 ? x - 1 : x, y];
				neighs[2] = outputImage[x + 1 < W ? x + 1 : x, y];

				neighs[3] = outputImage[x, y     > 0 ? y - 1 : y];
				neighs[4] = outputImage[x, y + 1 < H ? y + 1 : y];

				auto average = Color.black();

				foreach (i; 0 .. 5)
					average += neighs[i];

				average /= 5.0f;

				foreach (i; 0 .. 5)
				{
					if (tooDifferent(neighs[i], average))
					{
						needsAA[x, y] = true;
						break;
					}
				}
			}
		}

		foreach (b; buckets)
			foreach (y; b.min.y .. b.max.y)
				foreach (x; b.min.x .. b.max.x)
					renderPixelAA(x, y);
	}
	
private:

	/// Generates a list of buckets (image sub-rectangles) to be rendered, in a zigzag pattern
	box2i[] getBucketsList(uint frameWidth, uint frameHeight)
	{
		const int BUCKET_SIZE = scene.settings.bucketSize;
		int W = frameWidth;
		int H = frameHeight;
		int BW = (W - 1) / BUCKET_SIZE+ 1;
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

	bool drawRect(box2i r, const Color c)
	{
		//if (render_async && !rendering) return false;

		r.clip(outputImage.w, outputImage.h);

		//int rs = screen->format->Rshift;
		//int gs = screen->format->Gshift;
		//int bs = screen->format->Bshift;

		//Uint32 clr = c.toRGB32(rs, gs, bs);
		foreach (y; r.min.y .. r.max.y)
			foreach (x; r.min.x .. r.max.x)
				outputImage[x, y] = c;

		//SDL_UpdateRect(screen, r.x0, r.y0, r.w, r.h);

		return true;
	}

	/// Gets the color for a single pixel, without antialiasing
	Color renderPixelNoAA(int x, int y, int dx = 1, int dy = 1)
	{
		outputImage[x, y] = renderSample(x, y, dx, dy);
		return outputImage[x, y];
	}

	// gets the color for a single pixel, with antialiasing.
	// Assumes the pixel already holds some value.
	// This simply adds four more AA samples and averages the result.
	Color renderPixelAA(int x, int y)
	{
		enum double[2][5] kernel =
		[
			[ 0.0, 0.0 ],
			[ 0.3, 0.3 ],
			[ 0.6, 0.0 ],
			[ 0.0, 0.6 ],
			[ 0.6, 0.6 ],
		];

		Color accum = outputImage[x, y];
		foreach (sample; 1 .. 5) 
		{
			accum += renderSample(x + kernel[sample][0], y + kernel[sample][1]);
		}
		outputImage[x, y] = accum / 5;
		return outputImage[x, y];
	}

	// trace a ray through pixel coords (x, y).
	Color renderSample(double x, double y, int dx = 1, int dy = 1)
	{
		if (scene.camera.dof)
		{
			return renderSampleDof(x, y, dx, dy);
		}
		else if (scene.settings.GIEnabled)
		{
			return renderSampleGI(x, y, dx, dy);
		}
		else
		{
			return renderSampleDefault(x, y, dx, dy);
		}
	}

	Color renderSampleDof(double x, double y, int dx = 1, int dy = 1)
	{
		auto average = Color(0, 0, 0);
	
		for (int i = 0; i < scene.camera.numSamples; i++)
		{
			if (scene.camera.stereoSeparation == 0) // stereoscopic rendering?
				average += raytrace(scene.camera.getScreenRay(x + uniform(0.0, 1.0) * dx, y +uniform(0.0, 1.0) * dy));
			else
			{
				average += Color.combineStereo(
					raytrace(scene.camera.getScreenRay(x + uniform(0.0, 1.0) * dx, y + uniform(0.0, 1.0) * dy, Stereo3DOffset.Left)),
					raytrace(scene.camera.getScreenRay(x + uniform(0.0, 1.0) * dx, y + uniform(0.0, 1.0) * dy, Stereo3DOffset.Right))
					);
			}
		}
		return average / scene.camera.numSamples;
	}

	Color renderSampleGI(double x, double y, int dx = 1, int dy = 1)
	{
		auto average = Color(0, 0, 0);
	
		for (int i = 0; i < scene.settings.pathsPerPixel; i++)
		{
			average += pathtrace(
				scene.camera.getScreenRay(x + uniform(0.0, 1.0) * dx, y + uniform(0.0, 1.0) * dy),
				Color(1, 1, 1));
		}
		return average / scene.settings.pathsPerPixel;
	}

	Color renderSampleDefault(double x, double y, int dx = 1, int dy = 1)
	{
		if (scene.camera.stereoSeparation == 0)
			return raytrace(scene.camera.getScreenRay(x, y));
		else				
			return Color.combineStereo( // trace one ray through the left camera and one ray through the right, then combine the results
								 raytrace(scene.camera.getScreenRay(x, y, Stereo3DOffset.Left)),
								 raytrace(scene.camera.getScreenRay(x, y, Stereo3DOffset.Right)));
	}

	Color raytrace(const Ray ray)
	{
		return trace(ray, TraceType.Ray);
	}

	Color pathtrace(const Ray ray, const Color pathMultiplier)
	{
		return trace(ray, TraceType.Path);
	}	

	Color trace(const Ray ray, TraceType traceType)
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
				result.closestNode = cast(Node)node;
	
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
				return raytrace(result);
			case TraceType.Path:
				return pathtrace(result, Color(1, 1, 1));
		}
	}

	/// traces a ray in the scene and returns the visible light that comes from that direction
	Color raytrace(TraceResult result)
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

	Color pathtrace(TraceResult result, const Color pathMultiplier)
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
			size_t lightIndex = uniform(0, scene.lights.length);
			const Light light = scene.lights[lightIndex];
			size_t numLightSamples = light.getNumSamples();
		
			// choose a random sample of that light:
			size_t lightSampleIdx = uniform(0, numLightSamples);
		
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
		resultGi = pathtrace(w_out, pathMultiplier * brdfEval / pdf); // continue the path normally; accumulate the new term to the BRDF product
	
		return resultDirect + resultGi;
	}
}