// Mixed style: [[vk::binding]] + register(...) alongside auto-assigned.
struct PBRParams {
    float4 baseColorFactor;
    float metallicFactor;
    float roughnessFactor;
    float aoFactor;
};

// Slang: [[vk::binding(binding, set)]]
[[vk::binding(5, 0)]]
ConstantBuffer<PBRParams> pbrParams : register(b5);

// These use Slang's automatic binding assignment (starts from set 0,
// binding 0 for each descriptor type, skipping explicitly-bound slots)
Texture2D<float4> baseColorMap : register(t0);
Texture2D<float4> metallicRoughnessMap : register(t1);
Texture2D<float4> normalMap : register(t2);
Texture2D<float4> occlusionMap : register(t3);

[[vk::binding(0, 1)]]
SamplerState materialSampler : register(s0);

struct PSInput {
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
    float3 worldPos : TEXCOORD1;
};

[shader("fragment")]
float4 main(PSInput input) : SV_TARGET {
    float4 base = baseColorMap.Sample(materialSampler, input.uv) * pbrParams.baseColorFactor;
    float4 mr = metallicRoughnessMap.Sample(materialSampler, input.uv);
    float ao = occlusionMap.Sample(materialSampler, input.uv).r * pbrParams.aoFactor;
    return float4(base.rgb * ao, base.a);
}
