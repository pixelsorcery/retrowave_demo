#include "settings.h"

struct PS_INPUT
{
	float4 pos         : SV_POSITION;
	float2 tex         : TEXCOORD0;
};

static const float4 skyTop = float4(0.15f, 0.045f, 0.25f, 1.0f);
static const float4 skyBottom = float4(0.60f, 0.18f, 0.996f, 1.0f);

static const float2 resolution = float2(renderer::width, renderer::height);

void createRay(float2 pixel, inout float2 rayOrigin, inout float2 rayDirection)
{
	float2 p = (2 * float2(pixel.x, resolution.y - pixel.y - input.pos.y) - resolution) / resolution.y;

	float3 camPos = float3(0.0f, 1.0f, 5.0f);
	float3 camDir = float3(0.0f, 1.0f, 0.0f);

	// Create look-at matrix
	float3 dir   = normalize(camDir - camPos);
	float3 right = normalize(cross(camDir, float3(0.0f, 1.0f, 0.0f)));
	float3 up    = normalize(cross(right, dir));
}

float4 main(PS_INPUT input) : SV_TARGET
{
	float2 p = (2 * float2(input.pos.x, resolution.y - input.pos.y) - resolution) / resolution.y;

	float radius = 0.5f;
	float2 ctr = float2(0.0f, 0.3f);
	float4 output;
	//float2 diff = float2(input.tex.x, yAspect) - ctr;
	float2 diff = p - ctr;
	if (dot(diff, diff) < (radius * radius) && p.y > 0.0f)
	{
		// sun color
		output = float4(0.97f, 0.46f, 0.3f, 1.0f);
	}
	else
	{
		// sky
		output = lerp(skyTop, skyBottom, 1.0 - p.y/2);
	}

	//output = float4(p.x, p.y, 0.0, 1.0f);

	return output;
}