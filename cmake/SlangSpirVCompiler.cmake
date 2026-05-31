include_guard(GLOBAL)

#[=======================================================================
# add_slang_shaders
#
#   add_slang_shaders(
#     TARGET        <target>          # Custom target depending on all outputs
#     OUTPUT_DIR    <dir>             # Where .spv + .cppm files are written
#     NAMESPACE     <ns>              # C++ namespace segment inside Shaders::
#     SHADER_DIR    <dir>             # Dir containing .slang sources
#     COMPILER      <exe|target>      # slang-spirv-compiler path or CMake target
#     OPT_LEVEL     <0|1|2|3>         # Optimization level passed as -O flag to compiler
#     SHADERS
#       <stem>  <file>  <stage>  <entry>
#       ...
#   )
#
# Each row in SHADERS produces one add_custom_command:
#   <OUTPUT_DIR>/<stem>.spv
#   <OUTPUT_DIR>/<stem>.cppm
#
# Generated names (for stem="mesh_frag", NAMESPACE="MyApp"):
#   Module   = Shaders.MyApp.mesh_frag
#   Namespace = Shaders::MyApp
#   Class    = mesh_frag
#
# The shared module ShaderReflection.cppm is compiled once as an OBJECT
# library (slang_shared_reflection) that all consuming targets link against.
# Only the per-shader .cppm files are listed in SLANG_CPPM_FILES:
#
#   get_target_property(CPPM_FILES MyShaders SLANG_CPPM_FILES)
#   target_sources(my_app PRIVATE ${CPPM_FILES})
#   target_link_libraries(my_app PRIVATE slang_shared_reflection)
#
# The OBJECT library target name is also exposed via SLANG_SHARED_MODULE_TARGET.
# Generated .cppm files get COMPILE_OPTIONS "-Wno-c23-extensions".
#=======================================================================]

function(add_slang_shaders)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "TARGET;OUTPUT_DIR;NAMESPACE;SHADER_DIR;COMPILER;OPT_LEVEL" "SHADERS")

    if(NOT ARG_TARGET)
        message(FATAL_ERROR "add_slang_shaders: TARGET is required")
    endif()
    if(NOT ARG_OUTPUT_DIR)
        message(FATAL_ERROR "add_slang_shaders: OUTPUT_DIR is required")
    endif()
    if(NOT ARG_SHADERS)
        message(FATAL_ERROR "add_slang_shaders: SHADERS list is empty")
    endif()
    if(ARG_OPT_LEVEL)
        if(NOT ARG_OPT_LEVEL MATCHES "^[0-3]$")
            message(FATAL_ERROR "add_slang_shaders: OPT_LEVEL must be 0, 1, 2, or 3 (got '${ARG_OPT_LEVEL}')")
        endif()
    endif()

    # Resolve the compiler executable
    if(TARGET "${ARG_COMPILER}")
        set(_compiler_exe "$<TARGET_FILE:${ARG_COMPILER}>")
    elseif(ARG_COMPILER)
        set(_compiler_exe "${ARG_COMPILER}")
    else()
        find_program(_compiler_exe slang-spirv-compiler REQUIRED)
    endif()

    file(MAKE_DIRECTORY "${ARG_OUTPUT_DIR}")

    # ---- ShaderReflection.cppm (shared module) as an OBJECT library ----
    # Compiled once project-wide so multiple consuming targets can link
    # it without duplicating the module.  The target name is exposed on
    # every shader target via the SLANG_SHARED_MODULE_TARGET property.
    if(NOT SHARED_MODULE_DIR)
        get_filename_component(_helper_root "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/.." ABSOLUTE)
        set(SHARED_MODULE_DIR "${_helper_root}/src/cli_tool")
    endif()

    set(_shared_module_src "${SHARED_MODULE_DIR}/ShaderReflection.cppm")
    set(_shared_module_target "slang_shared_reflection")

    if(EXISTS "${_shared_module_src}")
        if(NOT TARGET "${_shared_module_target}")
            add_library("${_shared_module_target}" OBJECT)
            target_sources("${_shared_module_target}" PUBLIC
                FILE_SET CXX_MODULES
                BASE_DIRS "${SHARED_MODULE_DIR}"
                FILES "${_shared_module_src}"
            )
            target_compile_features("${_shared_module_target}" PRIVATE cxx_std_20)
            target_compile_options("${_shared_module_target}" PRIVATE
                $<$<CXX_COMPILER_ID:Clang,GNU>:-Wno-c23-extensions>
            )
        endif()
    else()
        message(WARNING "ShaderReflection.cppm not found at ${_shared_module_src}; "
                        "generated .cppm files will need the shared module provided separately")
    endif()

    # ---- per-shader .spv + .cppm ----
    set(_all_outputs "")

    list(LENGTH ARG_SHADERS _len)
    math(EXPR _num_groups "${_len} / 4")
    math(EXPR _last_group "${_num_groups} - 1")
    foreach(_i RANGE 0 ${_last_group})
        math(EXPR _base "${_i} * 4")
        list(GET ARG_SHADERS ${_base} _stem)
        if(NOT _stem)
            break()
        endif()
        math(EXPR _f "${_base} + 1")
        math(EXPR _s "${_base} + 2")
        math(EXPR _e "${_base} + 3")
        list(GET ARG_SHADERS ${_f} _file)
        list(GET ARG_SHADERS ${_s} _stage)
        list(GET ARG_SHADERS ${_e} _entry)

        set(_input  "${ARG_SHADER_DIR}/${_file}")
        set(_spv    "${ARG_OUTPUT_DIR}/${_stem}.spv")
        set(_cppm   "${ARG_OUTPUT_DIR}/${_stem}.cppm")

        if(ARG_OPT_LEVEL)
            set(_opt_flag "-O${ARG_OPT_LEVEL}")
        else()
            set(_opt_flag "")
        endif()

        add_custom_command(
            OUTPUT  "${_spv}" "${_cppm}"
            DEPENDS "${_input}" ${ARG_COMPILER}
            COMMAND "${_compiler_exe}"
                    "${_input}"
                    -e  "${_entry}"
                    -s  "${_stage}"
                    ${_opt_flag}
                    -o  "${ARG_OUTPUT_DIR}/${_stem}"
                    "${ARG_NAMESPACE}"
                    "${_stem}"
            COMMENT "Compiling ${_file} (${_stage}:${_entry}) -> ${_stem}"
        )

        set_source_files_properties("${_cppm}" PROPERTIES
            COMPILE_OPTIONS "-Wno-c23-extensions"
        )

        list(APPEND _all_outputs "${_spv}" "${_cppm}")
    endforeach()

    add_custom_target("${ARG_TARGET}" DEPENDS ${_all_outputs})

    # Collect just the per-shader .cppm files for easy consumption
    set(_all_cppms "")
    foreach(_i RANGE 0 ${_last_group})
        math(EXPR _base "${_i} * 4")
        list(GET ARG_SHADERS ${_base} _stem)
        if(NOT _stem)
            break()
        endif()
        list(APPEND _all_cppms "${ARG_OUTPUT_DIR}/${_stem}.cppm")
    endforeach()

    set_target_properties("${ARG_TARGET}" PROPERTIES
        SLANG_CPPM_FILES "${_all_cppms}"
    )

    if(TARGET "${_shared_module_target}")
        set_target_properties("${ARG_TARGET}" PROPERTIES
            SLANG_SHARED_MODULE_TARGET "${_shared_module_target}"
        )
    endif()
endfunction()
