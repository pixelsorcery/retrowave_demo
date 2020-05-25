struct PS_INPUT
{
	float4 pos         : SV_POSITION;
	float2 tex         : TEXCOORD0;
};

static const float2 resolution = float2(1280.0f, 720.0f);

void setupCamera(inout float3 camPosition, inout float3 camDirection)
{
	camPosition = float3(0.0f, 1.0f, 5.0f);
	camDirection = float3(0.0f, 1.0f, 0.0f);
}

void createRay(float2 pixel, inout float3 rayOrigin, inout float3 rayDirection)
{
	float2 p = (2 * float2(pixel.x, resolution.y - pixel.y - pixel.y) - resolution) / resolution.y;
}

float4 main(PS_INPUT input) : SV_TARGET
{
	float2 p = (2 * float2(input.pos.x, resolution.y - input.pos.y) - resolution) / resolution.y;
	if (p.y > 0.0) discard;

	float4 output = float4(0.0, p.y, 0.0f, 1.0f);
	return output;
}