include_guard(GLOBAL)

#[=======================================================================
# add_slang_shaders
#
#   add_slang_shaders(
#     TARGET        <target>          # Custom target depending on all outputs
#     OUTPUT_DIR    <dir>             # Where .spv + .cppm files are written
#     NAMESPACE     <ns>              # C++ namespace inside Shaders::
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
# Module name = <stem>
# Class name  = <PascalCase(stem)>Shader
# Namespace   = Shaders::<NAMESPACE>
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

    set(_all_outputs "")

    # Parse SHADERS: groups of 4 entries (stem file stage entry)
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
                    -n  "${ARG_NAMESPACE}"
                    -m  "${_stem}"
                    -c  "${_stem}Shader"
            COMMENT "Compiling ${_file} (${_stage}:${_entry}) -> ${_stem}"
        )

        set_source_files_properties("${_cppm}" PROPERTIES
            COMPILE_OPTIONS "-Wno-c23-extensions"
        )

        list(APPEND _all_outputs "${_spv}" "${_cppm}")
    endforeach()

    add_custom_target("${ARG_TARGET}" DEPENDS ${_all_outputs})
endfunction()
