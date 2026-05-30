// HLSL-compatibility style: [[vk::binding]] + register(...).
[[vk::binding(0, 0)]]
RWStructuredBuffer<float4> outputBuffer : register(u0);

[[vk::binding(1, 0)]]
StructuredBuffer<float4> inputBuffer : register(t0);

struct PushConstants {
    uint32_t numElements;
    float multiplier;
};

[[vk::push_constant]]
ConstantBuffer<PushConstants> pushConstants;

[shader("compute")]
[numthreads(64, 1, 1)]
void main(uint3 threadId : SV_DispatchThreadID) {
    uint32_t idx = threadId.x;
    if (idx < pushConstants.numElements) {
        outputBuffer[idx] = inputBuffer[idx] * pushConstants.multiplier;
    }
}
