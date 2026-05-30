// Pure Slang style: no register(...), no [[vk::binding]].
// Slang auto-assigns all Vulkan descriptor bindings.

struct SceneData {
    float3 lightDir;
    float4 ambientColor;
};

ConstantBuffer<SceneData> sceneData;

Texture2D<float4> albedo;
Texture2D<float4> normalMap;
Texture2D<float4> ormTexture;

SamplerState gSampler;

struct PSInput {
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
    float3 worldPos : TEXCOORD1;
};

[shader("fragment")]
float4 main(PSInput input) : SV_TARGET {
    float4 base = albedo.Sample(gSampler, input.uv);
    float3 n = normalMap.Sample(gSampler, input.uv).xyz * 2.0 - 1.0;
    return float4(base.rgb * sceneData.ambientColor.rgb, base.a);
}
