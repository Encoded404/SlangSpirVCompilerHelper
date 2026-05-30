// HLSL-compatibility style: register(...) slots without explicit
// [[vk::binding]] — Slang auto-assigns Vulkan bindings.

struct Light {
    float3 direction;
    float4 color;
    float intensity;
};

ConstantBuffer<Light> light : register(b0);

Texture2D<float4> baseColor : register(t0);
Texture2D<float4> normalMap : register(t1);
Texture2D<float4> ormTexture : register(t2); // occlusion/roughness/metallic

SamplerState gSampler : register(s0);

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
    n = normalize(n);
    float3 ld = normalize(light.direction);
    float diff = max(dot(n, ld), 0.0);
    return float4(base.rgb * light.color.rgb * diff * light.intensity, base.a);
}
