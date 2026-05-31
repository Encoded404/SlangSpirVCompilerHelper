#include <slang.h>

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <format>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace fs = std::filesystem;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
struct Args {
    fs::path input_file;
    std::string entry_point = "main";
    std::string stage_str = "fragment";
    fs::path output_prefix;
    std::vector<std::string> path_segments;
    bool help = false;
};

static SlangStage stageFromString(const std::string& s) {
    if (s == "vertex")             return SLANG_STAGE_VERTEX;
    if (s == "fragment")           return SLANG_STAGE_FRAGMENT;
    if (s == "compute")            return SLANG_STAGE_COMPUTE;
    if (s == "ray_generation")     return SLANG_STAGE_RAY_GENERATION;
    if (s == "intersection")       return SLANG_STAGE_INTERSECTION;
    if (s == "any_hit")            return SLANG_STAGE_ANY_HIT;
    if (s == "closest_hit")        return SLANG_STAGE_CLOSEST_HIT;
    if (s == "miss")               return SLANG_STAGE_MISS;
    if (s == "callable")           return SLANG_STAGE_CALLABLE;
    if (s == "mesh")               return SLANG_STAGE_MESH;
    if (s == "amplification")      return SLANG_STAGE_AMPLIFICATION;
    if (s == "hull")               return SLANG_STAGE_HULL;
    if (s == "domain")             return SLANG_STAGE_DOMAIN;
    if (s == "geometry")           return SLANG_STAGE_GEOMETRY;
    throw std::runtime_error("unknown stage: " + s);
}

static std::string_view stageEnumString(SlangStage s) {
    switch (s) {
    case SLANG_STAGE_VERTEX:         return "eVertex";
    case SLANG_STAGE_FRAGMENT:       return "eFragment";
    case SLANG_STAGE_COMPUTE:        return "eCompute";
    case SLANG_STAGE_RAY_GENERATION: return "eRayGeneration";
    case SLANG_STAGE_INTERSECTION:   return "eIntersection";
    case SLANG_STAGE_ANY_HIT:        return "eAnyHit";
    case SLANG_STAGE_CLOSEST_HIT:    return "eClosestHit";
    case SLANG_STAGE_MISS:           return "eMiss";
    case SLANG_STAGE_CALLABLE:       return "eCallable";
    case SLANG_STAGE_MESH:           return "eMesh";
    case SLANG_STAGE_AMPLIFICATION:  return "eAmplification";
    case SLANG_STAGE_HULL:           return "eHull";
    case SLANG_STAGE_DOMAIN:         return "eDomain";
    case SLANG_STAGE_GEOMETRY:       return "eGeometry";
    default: return "eFragment";
    }
}

static std::string toPascalCase(std::string_view s) {
    std::string result;
    bool capNext = true;
    for (char c : s) {
        if (c == '_' || c == '-' || c == '.') {
            capNext = true;
        } else if (capNext) {
            result += static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
            capNext = false;
        } else {
            result += c;
        }
    }
    return result;
}

// Map Slang type name -> BindingType enum string
static std::string_view bindingTypeEnum(std::string_view slangType) {
    if (slangType == "ConstantBuffer")           return "eUniformBuffer";
    if (slangType == "ParameterBlock")           return "eParameterBlock";
    if (slangType == "TextureBuffer")            return "eTextureBuffer";
    if (slangType == "ShaderStorageBuffer")      return "eStorageBuffer";
    if (slangType == "StructuredBuffer")         return "eStructuredBuffer";
    if (slangType == "ByteAddressBuffer")        return "eByteAddressBuffer";
    if (slangType == "Texture1D")                return "eTexture1D";
    if (slangType == "Texture2D")                return "eTexture2D";
    if (slangType == "Texture3D")                return "eTexture3D";
    if (slangType == "TextureCube")              return "eTextureCube";
    if (slangType == "SamplerState")             return "eSampler";
    if (slangType == "AccelerationStructure")    return "eAccelerationStructure";
    if (slangType == "SubpassInput")             return "eSubpassInput";
    return "eResource";
}

static Args parseArgs(int argc, char** argv) {
    Args a;
    if (argc < 2) { a.help = true; return a; }

    bool had_input = false;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "-h" || arg == "--help") { a.help = true; }
        else if (arg == "-e" && i + 1 < argc) a.entry_point = argv[++i];
        else if (arg == "-s" && i + 1 < argc) a.stage_str = argv[++i];
        else if (arg == "-o" && i + 1 < argc) a.output_prefix = argv[++i];
        else if (!had_input && arg[0] != '-') { a.input_file = arg; had_input = true; }
        else if (had_input && arg[0] != '-') { a.path_segments.push_back(arg); }
    }

    auto stem = a.input_file.stem().string();
    if (a.output_prefix.empty())
        a.output_prefix = stem;
    if (a.path_segments.empty()) {
        a.path_segments.push_back(stem);
        a.path_segments.push_back(toPascalCase(stem) + "Shader");
    }

    return a;
}

static void printUsage(const char* prog) {
    std::cerr << std::format(
        "usage: {} <input.slang> [-e entry] [-s stage] [-o prefix]\n"
        "       <namespace...> <class-name>\n"
        "\n"
        "Compiles a Slang shader to SPIR-V with Vulkan reflection.\n"
        "\n"
        "  input.slang        Slang source file\n"
        "  -e entry           Entry-point name (default: main)\n"
        "  -s stage           Shader stage: vertex | fragment | compute | ...\n"
        "  -o prefix          Output path prefix (default: <input stem>)\n"
        "  <namespace...>     One or more namespace segments (e.g. App Fragment)\n"
        "  <class-name>       Last segment = struct/class name\n"
        "\n"
        "The segments generate:\n"
        "  Module:   Shaders.<namespace...>.<class-name>\n"
        "  Namespace: Shaders::<namespace...>\n"
        "  Struct:   <class-name>\n"
        "\n"
        "Example:\n"
        "  {} triangle.slang App Fragment ComplexFragmentShader\n"
        "  -> module Shaders.App.Fragment.ComplexFragmentShader\n"
        "  -> namespace Shaders::App::Fragment\n"
        "  -> struct ComplexFragmentShader\n"
        "\n"
        "Outputs:\n"
        "  <prefix>.spv               SPIR-V binary\n"
        "  <prefix>.cppm              C++20 module with embed + reflection\n",
        prog, prog);
}

static std::string typeName(slang::TypeLayoutReflection* tl) {
    auto kind = tl->getKind();
    switch (kind) {
    case slang::TypeReflection::Kind::ConstantBuffer:   return "ConstantBuffer";
    case slang::TypeReflection::Kind::ParameterBlock:    return "ParameterBlock";
    case slang::TypeReflection::Kind::TextureBuffer:     return "TextureBuffer";
    case slang::TypeReflection::Kind::ShaderStorageBuffer: return "ShaderStorageBuffer";
    case slang::TypeReflection::Kind::Resource: {
        auto shape = tl->getResourceShape();
        auto base = shape & SLANG_RESOURCE_BASE_SHAPE_MASK;
        if (base == SLANG_STRUCTURED_BUFFER) return "StructuredBuffer";
        if (base == SLANG_BYTE_ADDRESS_BUFFER) return "ByteAddressBuffer";
        if (base == SLANG_TEXTURE_1D) return "Texture1D";
        if (base == SLANG_TEXTURE_2D) return "Texture2D";
        if (base == SLANG_TEXTURE_3D) return "Texture3D";
        if (base == SLANG_TEXTURE_CUBE) return "TextureCube";
        if (base == SLANG_ACCELERATION_STRUCTURE) return "AccelerationStructure";
        if (base == SLANG_TEXTURE_SUBPASS) return "SubpassInput";
        return "Resource";
    }
    case slang::TypeReflection::Kind::SamplerState:     return "SamplerState";
    case slang::TypeReflection::Kind::Array: {
        auto etl = tl->getElementTypeLayout();
        return typeName(etl) + "[]";
    }
    case slang::TypeReflection::Kind::Struct: {
        auto t = tl->getType();
        return t ? t->getName() : "struct";
    }
    case slang::TypeReflection::Kind::None:
        return "void";
    default:
        return tl->getName() ? tl->getName() : "unknown";
    }
}

struct BindingEntry {
    std::string type_enum; // e.g. "eUniformBuffer"
    uint32_t set;
    uint32_t binding;
    uint32_t count;
};

// Get the "real" type kind from the variable, accounting for layout
// unwrapping of container types (ParameterBlock, ConstantBuffer).
static slang::TypeReflection::Kind varTypeKind(slang::VariableLayoutReflection* var) {
    auto type = var->getType();
    if (type) return type->getKind();
    auto tl = var->getTypeLayout();
    return tl ? tl->getKind() : slang::TypeReflection::Kind::None;
}

// Returns true if a valid Vulkan descriptor binding was found.
static bool collectBindings(
    slang::VariableLayoutReflection* var,
    BindingEntry& out)
{
    auto tl = var->getTypeLayout();
    if (!tl) return false;

    bool found = false;
    int catCount = var->getCategoryCount();
    for (int ci = 0; ci < catCount; ++ci) {
        auto cat = var->getCategoryByIndex(ci);
        if (cat == slang::ParameterCategory::DescriptorTableSlot)
        {
            out.set = static_cast<uint32_t>(var->getBindingSpace(cat));
            out.binding = static_cast<uint32_t>(var->getOffset(cat));
            found = true;
            break;
        }
    }

    if (!found) return false;

    auto rtype = typeName(tl);
    out.type_enum = bindingTypeEnum(rtype).data();
    out.count = 1;
    return true;
}

// Heuristic: a struct variable with DescriptorTableSlot is a
// ParameterBlock (Slang unwraps ParameterBlock<T> to T in the layout).
static bool isUnwrappedParameterBlock(slang::VariableLayoutReflection* var) {
    auto vk = varTypeKind(var);
    if (vk == slang::TypeReflection::Kind::ParameterBlock)
        return true;
    if (vk != slang::TypeReflection::Kind::Struct)
        return false;
    int catCount = var->getCategoryCount();
    for (int ci = 0; ci < catCount; ++ci) {
        if (var->getCategoryByIndex(ci) == slang::ParameterCategory::DescriptorTableSlot)
            return true;
    }
    return false;
}

// Recursively walk parameters to find all bindings.
static void collectAllBindings(
    slang::VariableLayoutReflection* var,
    std::vector<BindingEntry>& entries)
{
    auto tl = var->getTypeLayout();
    if (!tl) return;
    auto varKind = varTypeKind(var);

    // For ConstantBuffer, emit the buffer itself but DON'T recurse into
    // fields — they are packed inside the buffer, not independent descriptors.
    if (varKind == slang::TypeReflection::Kind::ConstantBuffer) {
        BindingEntry entry;
        if (collectBindings(var, entry))
            entries.push_back(std::move(entry));
        return;
    }

    // For ParameterBlock, emit the block itself AND recurse into its
    // element — nested resources inside a ParameterBlock have their own
    // descriptor table slots.
    if (isUnwrappedParameterBlock(var)) {
        BindingEntry entry;
        if (collectBindings(var, entry)) {
            // Override type: Slang unwraps ParameterBlock to its element
            // struct, so collectBindings sees Struct kind, not ParameterBlock.
            entry.type_enum = "eParameterBlock";
            entries.push_back(std::move(entry));
        }
        auto* el = tl->getElementVarLayout();
        if (el) collectAllBindings(el, entries);
        return;
    }

    // For leaf resource types (Texture, Sampler, etc.), emit binding.
    BindingEntry entry;
    if (collectBindings(var, entry))
        entries.push_back(std::move(entry));

    // Recurse into struct fields to find nested resources.
    auto kind = tl->getKind();
    if (kind == slang::TypeReflection::Kind::Struct) {
        int fc = tl->getFieldCount();
        for (int i = 0; i < fc; ++i)
            collectAllBindings(tl->getFieldByIndex(i), entries);
    }
}

// ---------------------------------------------------------------------------
int main(int argc, char** argv) try {
    auto args = parseArgs(argc, argv);
    if (args.help) { printUsage(argv[0]); return args.help && argc < 2 ? 1 : 0; }

    // ---- read source file ----
    std::ifstream src_file(args.input_file, std::ios::binary | std::ios::ate);
    if (!src_file) throw std::runtime_error("cannot open " + args.input_file.string());
    src_file.seekg(0);
    std::string source((std::istreambuf_iterator<char>(src_file)),
                        std::istreambuf_iterator<char>());

    // ---- Slang API ----
    slang::IGlobalSession* globalSession = nullptr;
    if (SLANG_FAILED(slang::createGlobalSession(&globalSession)))
        throw std::runtime_error("createGlobalSession failed");

    slang::TargetDesc targetDesc = {};
    targetDesc.format = SLANG_SPIRV;
    targetDesc.profile = globalSession->findProfile("SPIRV_1_6");
    targetDesc.flags = SLANG_TARGET_FLAG_GENERATE_SPIRV_DIRECTLY;

    slang::SessionDesc sessionDesc = {};
    sessionDesc.targets = &targetDesc;
    sessionDesc.targetCount = 1;

    slang::ISession* session = nullptr;
    if (SLANG_FAILED(globalSession->createSession(sessionDesc, &session)))
        throw std::runtime_error("createSession failed");

    auto moduleName = args.input_file.stem().string();
    auto filePath = fs::absolute(args.input_file).string();

    slang::IBlob* diag = nullptr;
    auto* module = session->loadModuleFromSourceString(
        moduleName.c_str(), filePath.c_str(), source.c_str(), &diag);
    if (!module) {
        if (diag) {
            std::string msg(static_cast<const char*>(diag->getBufferPointer()),
                            diag->getBufferSize());
            diag->release();
            throw std::runtime_error("loadModule failed:\n" + msg);
        }
        throw std::runtime_error("loadModuleFromSourceString failed");
    }

    auto slangStage = stageFromString(args.stage_str);

    slang::IEntryPoint* entryPoint = nullptr;
    if (SLANG_FAILED(module->findAndCheckEntryPoint(
            args.entry_point.c_str(), slangStage, &entryPoint, &diag))) {
        if (diag) {
            std::string msg(static_cast<const char*>(diag->getBufferPointer()),
                            diag->getBufferSize());
            diag->release();
            throw std::runtime_error("findEntryPoint failed:\n" + msg);
        }
        throw std::runtime_error("findAndCheckEntryPoint failed");
    }

    slang::IComponentType* components[] = { module, entryPoint };
    slang::IComponentType* composite = nullptr;
    if (SLANG_FAILED(session->createCompositeComponentType(components, 2, &composite, &diag))) {
        if (diag) {
            std::string msg(static_cast<const char*>(diag->getBufferPointer()),
                            diag->getBufferSize());
            diag->release();
            throw std::runtime_error("createComposite failed:\n" + msg);
        }
        throw std::runtime_error("createCompositeComponentType failed");
    }

    slang::IComponentType* linkedProgram = nullptr;
    if (SLANG_FAILED(composite->link(&linkedProgram, &diag))) {
        if (diag) {
            std::string msg(static_cast<const char*>(diag->getBufferPointer()),
                            diag->getBufferSize());
            diag->release();
            throw std::runtime_error("link failed:\n" + msg);
        }
        throw std::runtime_error("link failed");
    }

    slang::IBlob* code = nullptr;
    if (SLANG_FAILED(linkedProgram->getEntryPointCode(0, 0, &code, &diag))) {
        if (diag) {
            std::string msg(static_cast<const char*>(diag->getBufferPointer()),
                            diag->getBufferSize());
            diag->release();
            throw std::runtime_error("getEntryPointCode failed:\n" + msg);
        }
        throw std::runtime_error("getEntryPointCode failed");
    }

    auto* layout = linkedProgram->getLayout(0, &diag);
    if (!layout) {
        if (diag) {
            std::string msg(static_cast<const char*>(diag->getBufferPointer()),
                            diag->getBufferSize());
            diag->release();
            throw std::runtime_error("getLayout failed:\n" + msg);
        }
        throw std::runtime_error("getLayout failed");
    }

    auto* entryPointLayout = layout->getEntryPointByIndex(0);
    auto actualStage = entryPointLayout ? entryPointLayout->getStage() : slangStage;

    // ---- collect bindings ----
    std::vector<BindingEntry> entries;
    int paramCount = layout->getParameterCount();
    for (int i = 0; i < paramCount; ++i) {
        auto* var = layout->getParameterByIndex(i);
        collectAllBindings(var, entries);
    }

    // ---- write .spv ----
    auto spv_path = fs::path(args.output_prefix).replace_extension(".spv");
    {
        const auto* spv_data = static_cast<const char*>(code->getBufferPointer());
        auto spv_size = code->getBufferSize();
        std::ofstream out(spv_path, std::ios::binary);
        out.write(spv_data, static_cast<std::streamsize>(spv_size));
    }

    // ---- build module / namespace / class names from path segments ----
    auto const& segs = args.path_segments;
    std::string module_name;
    std::string namespace_str;
    std::string const& class_name = segs.back();

    for (size_t i = 0; i < segs.size(); ++i) {
        if (i > 0) module_name += '.';
        module_name += segs[i];
        if (i + 1 < segs.size()) {
            if (i > 0) namespace_str += "::";
            namespace_str += segs[i];
        }
    }

    // ---- write .cppm ----
    auto cppm_path = fs::path(args.output_prefix).replace_extension(".cppm");
    {
        auto spv_stem = fs::path(args.output_prefix).filename().string();

        std::ofstream out(cppm_path);
        out << "// Auto-generated. Do not edit.\n";
        out << "// Source: " << fs::absolute(args.input_file).string() << "\n";
        out << "\n";
        out << "module;\n";
        out << "\n";
        out << "#include <array>\n";
        out << "#include <cstdint>\n";
        out << "#include <span>\n";
        out << "\n";
        out << "#include <vulkan/vulkan_raii.hpp>\n";
        out << "\n";
        out << "export module Shaders." << module_name << ";\n";
        out << "\n";
        out << "import ShaderReflection;\n";
        out << "\n";
        if (namespace_str.empty()) {
            out << "export namespace Shaders {\n";
        } else {
            out << "export namespace Shaders::" << namespace_str << " {\n";
        }
        out << "\n";
        out << "struct " << class_name << " {\n";
        out << "    [[nodiscard]] static std::span<const std::uint32_t> GetSpirvWords() noexcept {\n";
        out << "        // NOLINTNEXTLINE(modernize-avoid-c-arrays)\n";
        out << "        alignas(4) static constexpr unsigned char kBytes[] = {\n";
        out << "            #embed \"" << spv_stem << ".spv\"\n";
        out << "        };\n";
        out << "        return { reinterpret_cast<const std::uint32_t*>(kBytes),\n";
        out << "                 sizeof(kBytes) / sizeof(std::uint32_t) };\n";
        out << "    }\n";
        out << "\n";
        out << "    [[nodiscard]] static vk::raii::ShaderModule\n";
        out << "    CreateModule(vk::raii::Device const& device) {\n";
        out << "        auto const words = GetSpirvWords();\n";
        out << "        vk::ShaderModuleCreateInfo const info({},\n";
        out << "            words.size() * sizeof(std::uint32_t), words.data());\n";
        out << "        return vk::raii::ShaderModule(device, info);\n";
        out << "    }\n";
        out << "\n";
        out << "    [[nodiscard]] static constexpr ShaderStage GetStage() noexcept {\n";
        out << "        return ShaderStage::" << stageEnumString(actualStage) << ";\n";
        out << "    }\n";
        out << "\n";
        out << "    [[nodiscard]] static constexpr std::span<const Binding> GetBindings() noexcept {\n";
        out << "        return kBindings;\n";
        out << "    }\n";
        out << "\n";
        out << "private:\n";
        out << "    static constexpr std::array<Binding, " << entries.size() << "> kBindings{{\n";
        for (size_t i = 0; i < entries.size(); ++i) {
            auto& e = entries[i];
            out << "        { BindingType::" << e.type_enum << ", "
                << e.set << ", " << e.binding << ", " << e.count << " }";
            if (i + 1 < entries.size()) out << ",";
            out << "\n";
        }
        out << "    }};\n";
        out << "};\n";
        out << "\n";
        if (namespace_str.empty()) {
            out << "} // namespace Shaders\n";
        } else {
            out << "} // namespace Shaders::" << namespace_str << "\n";
        }
    }

    // ---- cleanup ----
    code->release();
    linkedProgram->release();
    composite->release();
    entryPoint->release();
    module->release();
    session->release();
    globalSession->release();

    //std::cout << std::format("ok: {} {}\n", spv_path.string(), cppm_path.string());
    return 0;

} catch (std::exception const& e) {
    std::cerr << "error: " << e.what() << "\n";
    return 1;
}
