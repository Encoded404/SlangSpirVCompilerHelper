struct SceneData {
    float3 lightDir;
    float4 cameraPos;
};

struct Material {
    Texture2D<float4> albedo;
    Texture2D<float4> normal;
    Texture2D<float4> metallicRoughness;
    SamplerState samp;
};

[[vk::binding(0, 0)]]
ParameterBlock<Material> material;

[[vk::binding(0, 1)]]
ConstantBuffer<SceneData> sceneData : register(b0);

struct PSInput {
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
    float3 worldPos : TEXCOORD1;
};

[shader("fragment")]
float4 main(PSInput input) : SV_TARGET {
    float4 albedo = material.albedo.Sample(material.samp, input.uv);
    float3 n = material.normal.Sample(material.samp, input.uv).xyz * 2.0 - 1.0;
    float3 viewDir = normalize(sceneData.cameraPos.xyz - input.worldPos);
    float3 lightDirN = normalize(sceneData.lightDir);
    float diff = max(dot(n, lightDirN), 0.0);
    float3 halfDir = normalize(lightDirN + viewDir);
    float spec = pow(max(dot(n, halfDir), 0.0), 64.0);
    return float4(albedo.rgb * (0.3 + diff + spec * 0.5), albedo.a);
}
