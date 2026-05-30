// HLSL-compatibility style: [[vk::binding]] + register(...).
struct SceneData {
    float3 lightDir;
    float4 ambientColor;
    float4x4 viewProj;
};

[[vk::binding(0, 0)]]
ConstantBuffer<SceneData> sceneData : register(b0);

[[vk::binding(1, 0)]]
Texture2D<float4> albedo : register(t0);

[[vk::binding(2, 0)]]
SamplerState albedoSampler : register(s0);

struct PSInput {
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
    float3 worldPos : TEXCOORD1;
};

[shader("fragment")]
float4 main(PSInput input) : SV_TARGET {
    float4 texColor = albedo.Sample(albedoSampler, input.uv);
    float3 lightDirN = normalize(sceneData.lightDir);
    float diff = max(dot(input.normal, lightDirN), 0.0);
    return float4(texColor.rgb * (sceneData.ambientColor.rgb + diff), texColor.a);
}
