#include "settings.h"

#define NONE  -1
#define PLANE  0
#define SPHERE 1

struct PS_INPUT
{
	float4 pos         : SV_POSITION;
	float2 tex         : TEXCOORD0;
};

static const float4 skyTop = float4(0.15f, 0.045f, 0.25f, 1.0f);
static const float4 skyBottom = float4(0.60f, 0.18f, 0.996f, 1.0f);

static const float2 resolution = float2(renderer::width, renderer::height);

float traceRay(float3 rayOrigin, float3 rayDir, inout float3 pos, inout float3 nor, inout int objType)
{
	float tmin = 10000;
	pos = float3(0.0f, 0.0f, 0.0f);
	nor = float3(0.0f, 0.0f, 0.0f);
	objType = NONE;

	// raytrace plane
	// ray plane intersection, since normal is (0, 1, 0) only y component matters
	// simplified version of 
	//float t = -dot(rayOrigin-0.01, nor)/dot(rayDir, nor);
	float t = (0.01 - rayOrigin.y) / rayDir.y;

	if (t > 0.0)
	{
		tmin = t;
		nor = float3(0.0f, 1.0f, 0.0f);
		pos = rayOrigin + rayDir * t;
		objType = PLANE;
	}

	return tmin;
}

void createRay(in float4 pixel, inout float3 rayOrigin, inout float3 rayDirection)
{
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

float4 main(PS_INPUT input) : SV_TARGET
{
	input.pos.y = resolution.y - input.pos.y; // invert y
	float2 p = (2 * input.pos.xy - resolution) / resolution.y;

	float radius = 0.5f;
	float2 ctr = float2(0.0f, 0.3f);
	float4 output;
	float2 diff = p - ctr;
	if (dot(diff, diff) < (radius * radius) && p.y > 0.0f)
	{
		// sun color
		output = float4(0.97f, 0.46f, 0.3f, 1.0f);
	}
	else
	{
		// sky
		output = lerp(skyTop, skyBottom, .5 - p.y/2);
	}

	float3 rayDir;
	float3 rayOrigin;
	float3 rayOriginDdx;
	float3 rayDirDdx;
	float3 rayOriginDdy;
	float3 rayDirDdy;

	// create main ray and rays for partial derivatives basically one pixel to right and one pixel down
	createRay(input.pos, rayOrigin, rayDir);
	createRay(input.pos + float4(1.0, 0.0, 0.0, 0.0), rayOriginDdx, rayDirDdx);
	createRay(input.pos + float4(0.0, 1.0, 0.0, 0.0), rayOriginDdy, rayDirDdy);

	// Raytrace
	float3 pos;
	float3 nor;
	int objectType = NONE;

	float t = traceRay(rayOrigin, rayDir, pos, nor, objectType);
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
	float3 ddx_pos = rayOriginDdx - rayDirDdx * dot(rayOriginDdx - pos, nor) / dot(rayDirDdx, nor);
	float3 ddy_pos = rayOriginDdy - rayDirDdy * dot(rayOriginDdy - pos, nor) / dot(rayDirDdy, nor);

	if (objectType == PLANE)
	{
		output = float4(1.0, 1.0, 1.0, 1.0f);
	}

	return output;
}