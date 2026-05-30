module;

#include <cstdint>

export module ShaderReflection;

export enum class ShaderStage : std::uint8_t {
    eVertex = 0,
    eFragment,
    eCompute,
    eRayGeneration,
    eIntersection,
    eAnyHit,
    eClosestHit,
    eMiss,
    eCallable,
    eMesh,
    eAmplification,
    eHull,
    eDomain,
    eGeometry,
};

export enum class BindingType : std::uint8_t {
    eUniformBuffer,
    eStorageBuffer,
    eStructuredBuffer,
    eByteAddressBuffer,
    eTexture1D,
    eTexture2D,
    eTexture3D,
    eTextureCube,
    eSampler,
    eAccelerationStructure,
    eSubpassInput,
    eParameterBlock,
    eTextureBuffer,
    eResource,
};

export struct Binding {
    BindingType type;
    std::uint32_t set;
    std::uint32_t binding;
    std::uint32_t count;
};
