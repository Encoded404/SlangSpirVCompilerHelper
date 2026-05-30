// Pure Slang style with explicit [[vk::binding]] annotations.
// No register(...) — Slang ignores HLSL register slots when
// vk::binding is present.

struct Light {
    float3 direction;
    float4 color;
    float intensity;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Light> light;

[[vk::binding(1, 0)]]
Texture2D<float4> baseColor;

[[vk::binding(2, 0)]]
Texture2D<float4> normalMap;

[[vk::binding(3, 0)]]
SamplerState gSampler;

struct PSInput {
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
    float3 worldPos : TEXCOORD1;
};

[shader("fragment")]
float4 main(PSInput input) : SV_TARGET {
    float4 base = baseColor.Sample(gSampler, input.uv);
    float3 n = normalMap.Sample(gSampler, input.uv).xyz * 2.0 - 1.0;
    float3 ld = normalize(light.direction);
    float diff = max(dot(n, ld), 0.0);
    return float4(base.rgb * light.color.rgb * diff * light.intensity, base.a);
}
