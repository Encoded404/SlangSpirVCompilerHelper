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
#   Module   = Shaders.MyApp.mesh_fragShader
#   Namespace = Shaders::MyApp
#   Class    = mesh_fragShader
#
# The shared module ShaderReflection.cppm is automatically copied into
# OUTPUT_DIR so the generated .cppm files can import it.  All .cppm
# files are listed in the target property SLANG_CPPM_FILES:
#
#   get_target_property(CPPM_FILES MyShaders SLANG_CPPM_FILES)
#   target_sources(my_app PRIVATE ${CPPM_FILES})
#
# Generated .cppm files get COMPILE_OPTIONS "-Wno-c23-extensions".
#=======================================================================]

function(add_slang_shaders)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "TARGET;OUTPUT_DIR;NAMESPACE;SHADER_DIR;COMPILER" "SHADERS")

    if(NOT ARG_TARGET)
        message(FATAL_ERROR "add_slang_shaders: TARGET is required")
    endif()
    if(NOT ARG_OUTPUT_DIR)
        message(FATAL_ERROR "add_slang_shaders: OUTPUT_DIR is required")
    endif()
    if(NOT ARG_SHADERS)
        message(FATAL_ERROR "add_slang_shaders: SHADERS list is empty")
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

    # ---- ShaderReflection.cppm (shared module) ----
    # The shared module lives alongside this cmake file in the slang-
    # spirv-compiler-helper tree.  If you installed/cmake-bundled this
    # module elsewhere, adjust SHARED_MODULE_DIR or override the path
    # before calling add_slang_shaders().
    if(NOT SHARED_MODULE_DIR)
        get_filename_component(_helper_root "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
        set(SHARED_MODULE_DIR "${_helper_root}/src/cli_tool")
    endif()

    set(_shared_module_src "${SHARED_MODULE_DIR}/ShaderReflection.cppm")
    set(_shared_module_dst "${ARG_OUTPUT_DIR}/ShaderReflection.cppm")

    if(EXISTS "${_shared_module_src}")
        add_custom_command(
            OUTPUT  "${_shared_module_dst}"
            DEPENDS "${_shared_module_src}"
            COMMAND "${CMAKE_COMMAND}" -E copy "${_shared_module_src}" "${_shared_module_dst}"
            COMMENT "Copying ShaderReflection.cppm"
        )
        set_source_files_properties("${_shared_module_dst}" PROPERTIES
            COMPILE_OPTIONS "-Wno-c23-extensions"
        )
    else()
        message(WARNING "ShaderReflection.cppm not found at ${_shared_module_src}; "
                        "generated .cppm files will need the shared module provided separately")
    endif()

    # ---- per-shader .spv + .cppm ----
    set(_all_outputs "${_shared_module_dst}")

    list(LENGTH ARG_SHADERS _len)
    math(EXPR _num_groups "${_len} / 4")
    foreach(_i RANGE 0 ${_num_groups})
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

        add_custom_command(
            OUTPUT  "${_spv}" "${_cppm}"
            DEPENDS "${_input}" ${ARG_COMPILER}
            COMMAND "${_compiler_exe}"
                    "${_input}"
                    -e  "${_entry}"
                    -s  "${_stage}"
                    -o  "${ARG_OUTPUT_DIR}/${_stem}"
                    "${ARG_NAMESPACE}"
                    "${_stem}Shader"
            COMMENT "Compiling ${_file} (${_stage}:${_entry}) -> ${_stem}"
        )

        set_source_files_properties("${_cppm}" PROPERTIES
            COMPILE_OPTIONS "-Wno-c23-extensions"
        )

        list(APPEND _all_outputs "${_spv}" "${_cppm}")
    endforeach()

    add_custom_target("${ARG_TARGET}" DEPENDS ${_all_outputs})

    # Collect just the .cppm files for easy consumption
    set(_all_cppms "${_shared_module_dst}")
    foreach(_i RANGE 0 ${_num_groups})
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
endfunction()
