#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPILER="${SCRIPT_DIR}/../build/bin/Debug/slang-spirv-compiler"
SHADER_DIR="${SCRIPT_DIR}/shaders"
OUTPUT_DIR="${SCRIPT_DIR}/output"

if [ ! -f "$COMPILER" ]; then
    echo "error: compiler not found at $COMPILER"
    echo "Build it first: cmake --build ${SCRIPT_DIR}/../build --parallel"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "=== Compiling example shaders ==="

"$COMPILER" "${SHADER_DIR}/triangle.slang"  -e main -s fragment  -o "${OUTPUT_DIR}/triangle_frag"  -n Examples -m TriangleFrag  -c TriangleFragmentShader
echo "  triangle_frag.spv + triangle_frag.cppm"

"$COMPILER" "${SHADER_DIR}/vertex.slang"    -e main -s vertex    -o "${OUTPUT_DIR}/vertex_main"    -n Examples -m VertexMain    -c VertexShader
echo "  vertex_main.spv + vertex_main.cppm"

"$COMPILER" "${SHADER_DIR}/compute.slang"   -e main -s compute   -o "${OUTPUT_DIR}/compute_main"   -n Examples -m ComputeMain   -c ComputeShader
echo "  compute_main.spv + compute_main.cppm"

"$COMPILER" "${SHADER_DIR}/parameter_block.slang" -e main -s fragment -o "${OUTPUT_DIR}/pb_main" -n Examples -m PBFrag -c ParameterBlockShader
echo "  pb_main.spv + pb_main.cppm"

# HLSL-compatibility style with register(...) but no vk::binding
"$COMPILER" "${SHADER_DIR}/hlsl_compat_auto.slang" -e main -s fragment -o "${OUTPUT_DIR}/hlsl_compat_auto" -n Examples -m HlslCompatAuto -c HlslCompatAutoShader
echo "  hlsl_compat_auto.spv + hlsl_compat_auto.cppm"

"$COMPILER" "${SHADER_DIR}/mixed_binding.slang" -e main -s fragment -o "${OUTPUT_DIR}/mixed_binding" -n Examples -m MixedBinding -c MixedBindingShader
echo "  mixed_binding.spv + mixed_binding.cppm"

# Pure Slang style (no register, no vk::binding)
"$COMPILER" "${SHADER_DIR}/pure_slang.slang" -e main -s fragment -o "${OUTPUT_DIR}/pure_slang" -n Examples -m PureSlang -c PureSlangShader
echo "  pure_slang.spv + pure_slang.cppm"

# Pure Slang style with explicit vk::binding annotations
"$COMPILER" "${SHADER_DIR}/pure_slang_explicit.slang" -e main -s fragment -o "${OUTPUT_DIR}/pure_slang_explicit" -n Examples -m PureSlangExplicit -c PureSlangExplicitShader
echo "  pure_slang_explicit.spv + pure_slang_explicit.cppm"

echo ""
echo "=== Generated files ==="
ls -1 "${OUTPUT_DIR}/"
echo ""
echo "Done."
