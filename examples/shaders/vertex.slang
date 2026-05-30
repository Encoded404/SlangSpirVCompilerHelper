// HLSL-compatibility style: [[vk::binding]] + register(...).
struct VertexInput {
    float3 position : POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
};

struct PSInput {
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
    float3 worldPos : TEXCOORD1;
};

struct Transform {
    float4x4 model;
    float4x4 viewProj;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Transform> transform : register(b0);

[shader("vertex")]
PSInput main(VertexInput input) {
    PSInput output;
    float4 worldPos = mul(transform.model, float4(input.position, 1.0));
    output.position = mul(transform.viewProj, worldPos);
    output.uv = input.uv;
    output.normal = normalize(mul((float3x3)transform.model, input.normal));
    output.worldPos = worldPos.xyz;
    return output;
}
