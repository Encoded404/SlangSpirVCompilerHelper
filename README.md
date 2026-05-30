# slang-spirv-compiler-helper

CLI tool that compiles [Slang](https://github.com/shader-slang/slang) shaders to SPIR-V and generates C++20 module files (`.cppm`) with `#embed` for the bytecode and compile-time reflection data.

## Layout

```
slang-spirv-compiler-helper/
├── CMakeLists.txt
├── CMakePresets.json
├── vcpkg.json
├── cmake/
│   ├── ConfigureClangTidy.cmake
│   └── SlangSpirVCompiler.cmake       # CMake module for build-system integration
├── src/
│   ├── CMakeLists.txt
│   └── cli_tool/
│       ├── CMakeLists.txt
│       ├── main.cpp                    # CLI entry point
│       └── ShaderReflection.cppm       # Shared type module (copy into your project)
├── examples/
│   ├── compile_examples.sh            # Run to test all example shaders
│   ├── output/                        # Generated .spv + .cppm files
│   └── shaders/                       # Example .slang files
└── external/
    └── cppLoggingInterface/
```

## Prerequisites

- CMake ≥ 3.15
- A C++20-capable compiler
- vcpkg available with `VCPKG_ROOT` set

## Build

```bash
cmake --preset default
cmake --build build --parallel
```

The CLI executable is placed at `build/bin/<config>/slang-spirv-compiler`.

## Usage

```bash
slang-spirv-compiler <input.slang> [-e entry] [-s stage] [-o prefix] \
    <namespace...> <class-name>
```

Each invocation produces two files:
- `<prefix>.spv`  — SPIR-V binary
- `<prefix>.cppm` — C++20 module with `#embed`d bytecode + `constexpr` reflection

The positional arguments define the module, namespace, and struct names:

| Argument | Example | Produces |
|---|---|---|
| `App Fragment` | namespace segments | module `Shaders.App.Fragment.…`<br>namespace `Shaders::App::Fragment` |
| `ComplexFragmentShader` | last segment = struct name | `struct ComplexFragmentShader` |

### Example

```bash
slang-spirv-compiler shaders/triangle.slang -e main -s fragment \
    -o build/generated/triangle MyApp Triangle
```

Generated `triangle.cppm`:

```cpp
export module Shaders.MyApp.Triangle;
import ShaderReflection;
export namespace Shaders::MyApp {
struct Triangle {
    static std::span<const std::uint32_t> GetSpirvWords() noexcept { ... }  // #embed
    static vk::raii::ShaderModule CreateModule(vk::raii::Device const&) { ... }
    static constexpr ShaderStage GetStage() noexcept { return ShaderStage::eFragment; }
    static constexpr std::span<const Binding> GetBindings() noexcept { ... }
private:
    static constexpr std::array<Binding, 3> kBindings_{{ ... }};
};
}
```

## CMake integration

Include the module, compile shaders, and add them to your target:

```cmake
# Option A: add to module path
list(APPEND CMAKE_MODULE_PATH "/path/to/slang-spirv-compiler-helper/cmake")
include(SlangSpirVCompiler)

# Option B: include directly
# include(/path/to/slang-spirv-compiler-helper/cmake/SlangSpirVCompiler.cmake)

# Compile shaders — each row creates an add_custom_command so CMake
# rebuilds only the shaders whose source changed.
# Generated module: Shaders.MyApp.mesh_vert (etc.)
# Generated namespace: Shaders::MyApp
# Generated struct: mesh_vert (etc.)
add_slang_shaders(
    TARGET      MyShaders
    OUTPUT_DIR  "${CMAKE_BINARY_DIR}/generated/shaders"
    NAMESPACE   MyApp
    SHADER_DIR  "${CMAKE_SOURCE_DIR}/shaders"
    COMPILER    slang-spirv-compiler
    SHADERS
        mesh_vert  mesh.slang    vertex   main
        mesh_frag  mesh.slang    fragment main
        compute    compute.slang compute  computeMain
)

# The function automatically copies ShaderReflection.cppm (the shared
# module) into OUTPUT_DIR and lists all .cppm files in the target
# property SLANG_CPPM_FILES:
get_target_property(SHADER_CPPM MyShaders SLANG_CPPM_FILES)
target_sources(my_app PRIVATE ${SHADER_CPPM})
```

If you keep the cmake module outside the project tree (e.g. installed), set `SHARED_MODULE_DIR` before calling `add_slang_shaders`:

```cmake
set(SHARED_MODULE_DIR "/path/to/ShaderReflection.cppm/dir")
include(/path/to/SlangSpirVCompiler.cmake)
```

### Manual use (without cmake module)

If you don't use `add_slang_shaders()`, copy `ShaderReflection.cppm` from `src/cli_tool/` into your project and add generated `.cppm` files with:

```cmake
set_source_files_properties(generated/triangle.cppm PROPERTIES
    COMPILE_OPTIONS "-Wno-c23-extensions"
)
```

## Examples

Run `examples/compile_examples.sh` after building to compile all 8 example shaders:

| File | Style | Stage | Bindings |
|---|---|---|---|
| `triangle.slang` | HLSL compat `register` + `[[vk::binding]]` | fragment | ConstantBuffer, Texture2D, Sampler |
| `vertex.slang` | HLSL compat `register` + `[[vk::binding]]` | vertex | ConstantBuffer |
| `compute.slang` | HLSL compat `register` + `[[vk::binding]]` | compute | RW/RO StructuredBuffer |
| `parameter_block.slang` | `register` + `[[vk::binding]]` | fragment | ParameterBlock + ConstantBuffer |
| `hlsl_compat_auto.slang` | `register`, no `[[vk::binding]]` | fragment | Auto-assigned bindings |
| `mixed_binding.slang` | Mixed explicit + auto | fragment | Explicit ConstantBuffer + auto textures |
| `pure_slang.slang` | Pure Slang, no annotations | fragment | Auto-assigned |
| `pure_slang_explicit.slang` | Pure Slang + `[[vk::binding]]` | fragment | Fully explicit |
