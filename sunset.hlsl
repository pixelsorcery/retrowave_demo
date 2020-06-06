#include "settings.h"

#define NONE  -1
#define PLANE  0
#define SPHERE 1

#define TMAX 10000

static const float N = 50.0;

struct Constants
{
	float time;
};

ConstantBuffer<Constants> cb : register(b0);

struct PS_INPUT
{
	float4 pos : SV_POSITION;
	float2 tex : TEXCOORD0;
};

static const float4 skyTop = float4(0.15f, 0.045f, 0.25f, 1.0f);
static const float4 skyBottom = float4(0.60f, 0.18f, 0.996f, 1.0f);

static const float2 resolution = float2(renderer::width, renderer::height);

// see https://www.iquilezles.org/www/articles/checkerfiltering/checkerfiltering.htm
float gridTextureGradBoxFilter(float2 uv, float2 ddx, float2 ddy)
{
	uv += 0.5f;
	float2 w = max(abs(ddx), abs(ddy)) + 0.01;
	float2 a = uv + 0.5 * w;
	float2 b = uv - 0.5 * w;

	float2 i = (floor(a) + min(frac(a) * N, 1.0) -
		floor(b) - min(frac(b) * N, 1.0)) / (N * w);

	return (1.0 - i.x) * (1.0 - i.y);
}

// Generate color based on object uv and position
float gridTexture(float2 uv)
{
	uv += 0.5f;
	float2 i = step(frac(uv), float2(1.0 / N, 1.0 / N));
	return (1.0 - i.x) * (1.0 - i.y);
}

// Calculate uv coordinate of object
float2 texCoords(float3 pos, int objectType)
{
	float2 uv;
	if (objectType == PLANE)
	{
		uv = pos.xz;
	}
	else if (objectType == SPHERE)
	{
		// Todo
	}

	uv.y -= cb.time * 10;
	return 0.5 * uv;
}

// Check if ray intersects with an object and return position, distance along ray, normal and object type
float traceRay(float3 rayOrigin, float3 rayDir, inout float3 pos, inout float3 nor, inout int objType)
{
	float tmin = TMAX;
	pos = float3(0.0f, 0.0f, 0.0f);
	nor = float3(0.0f, 0.0f, 0.0f);
	objType = NONE;

	// Raytrace plane
	// ray plane intersection, since normal is (0, 1, 0) only y component matters
	// simplified version of 
	// float t = -dot(rayOrigin-0.01, nor)/dot(rayDir, nor);
	float t = (-1.0 - rayOrigin.y) / rayDir.y;

	if (t > 0.0)
	{
		tmin = t;
		nor = float3(0.0f, 1.0f, 0.0f);
		pos = rayOrigin + rayDir * t;
		objType = PLANE;
	}

	return tmin;
}

// Creates ray based on camera position
void createRay(in float4 pixel, inout float3 rayOrigin, inout float3 rayDirection)
{
	// Remap input position into ndc space in range -1..1
	float2 p = (2 * pixel.xy - resolution) / resolution.y;

	float3 camPos = float3(0.0f, 1.0f, 5.0f);
	float3 camDir = float3(0.0f, 1.0f, 0.0f);

	// Create look-at matrix with Gram–Schmidt process
	float3 dir   = normalize(camDir - camPos);
	float3 right = normalize(cross(dir, float3(0.0f, 1.0f, 0.0f)));
	float3 up    = normalize(cross(right, dir));

	// View ray
	rayDirection = normalize(p.x * right + p.y * up + 2.0f * dir);
	rayOrigin = camPos;
}

float rand(float x)
{
	return frac(sin(x) * 100000.0f);
}

float4 main(PS_INPUT input) : SV_TARGET
{
	// Invert y
	input.pos.y = resolution.y - input.pos.y;
	// Remap input position into ndc space in range -1..1
	float2 p = (2 * input.pos.xy - resolution) / resolution.y;

	float radius = 0.5f;
	float2 ctr = float2(0.0f, 0.3f);
	float4 output;
	float2 diff = p - ctr;

	// get random heights of buildings
	float width = 50.0;
	float skylineHeight = rand((trunc(p.x* width) % width));

	// have them get smaller along the edges
	float falloffFactor = 0.7;
	skylineHeight *= 1.0 - abs(p.x) * falloffFactor;

	float t = TMAX;
	if (p.y > 0.0 && p.y * 2.7 < skylineHeight)
	{
		output = float4(0.1, 0.1, 0.1, 1.0);
		output *= rand(p.y) * rand(p.x) * 3.0f;
		t = 50.0f;
	}
	else if (dot(diff, diff) < (radius * radius) && p.y > 0.0f)
	{
		// Sun color
		output = float4(0.97f, 0.46f, 0.3f, 1.0f) * step(frac(p.y * 15) - p.y/5, 8/10.0);
		t = 10.0;
	}
	else
	{
		// Sky
		output = lerp(skyTop, skyBottom, .5 - p.y/2);
	}

	float3 rayDir;
	float3 rayOrigin;
	float3 rayOriginDdx;
	float3 rayDirDdx;
	float3 rayOriginDdy;
	float3 rayDirDdy;

	// Create main ray and rays for partial derivatives basically one pixel to right and one pixel down
	createRay(input.pos, rayOrigin, rayDir);
	createRay(input.pos + float4(1.0, 0.0, 0.0, 0.0), rayOriginDdx, rayDirDdx);
	createRay(input.pos + float4(0.0, 1.0, 0.0, 0.0), rayOriginDdy, rayDirDdy);

	// Raytrace
	float3 pos;
	float3 nor;
	int objectType = NONE;

	float groundt = traceRay(rayOrigin, rayDir, pos, nor, objectType);

	t = min(groundt, t);

	// compute ray differentials, intersect ray with tangent plane to the surface
	//
	// Take the new position and subtract the hit position from original camera ray.
	// This will give us a ray from the position to the new ddx/ddy origin. Then
	// we take a dot product with the normal which projects the ray in the direction
	// of the normal. Basically it takes the component of the ray that is parallel
	// to the normal. Then we do the same with the ray direction and the normal and 
	// this gives us a small amount, basically the amount of ray in the direction of 
	// the same normal. Then we divide the ddx/y - position projection with the new ray
	// and we get the amnt we have to multiply to reach the new ddx pos on the tangent
	// plane.
	float3 posDdx = rayOriginDdx - rayDirDdx * dot(rayOriginDdx - pos, nor) / dot(rayDirDdx, nor);
	float3 posDdy = rayOriginDdy - rayDirDdy * dot(rayOriginDdy - pos, nor) / dot(rayDirDdy, nor);

	// Calculate uv coords
	float2 uv = texCoords(pos, objectType);

	// Texture diffs
	float2 uvDdx = texCoords(posDdx, objectType) - uv;
	float2 uvDdy = texCoords(posDdy, objectType) - uv;

	if (objectType == PLANE)
	{
		float color = gridTextureGradBoxFilter(uv, uvDdx, uvDdy);
		output = lerp(float4(217.0 / 255.0, 117.0 / 255.0, 217.0 / 255.0, 1.0f), float4(133.0 / 255.0, 46.0 / 255.0, 106.0 / 255.0, 1.0f), color);
	}

	// fog
	if (t < TMAX)
	{
		output = lerp(output, skyBottom, 1.0 - exp(-0.0001 * t * t));
	}

	return output;
}