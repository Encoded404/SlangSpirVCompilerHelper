add_executable(${CLI_TOOL_TARGET})
target_sources(${CLI_TOOL_TARGET} PRIVATE
    main.cpp
)

find_package(slang CONFIG REQUIRED)

target_link_libraries(${CLI_TOOL_TARGET} PRIVATE
    slang::slang
)

set_target_properties(${CLI_TOOL_TARGET} PROPERTIES OUTPUT_NAME ${CLI_TOOL_TARGET})

if(OUTPUT_PATH)
    set_target_properties(${CLI_TOOL_TARGET} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${OUTPUT_PATH})
endif()

target_compile_features(${CLI_TOOL_TARGET} PRIVATE cxx_std_20)

target_compile_options(${CLI_TOOL_TARGET} PRIVATE
    $<$<CXX_COMPILER_ID:GNU>:-Wall -Wextra -Wpedantic>
    $<$<CXX_COMPILER_ID:Clang>:-Wall -Wextra -Wpedantic>
    $<$<CXX_COMPILER_ID:MSVC>:/W4 /permissive->
)

if(CMAKE_CONFIGURATION_TYPES)
    target_compile_options(${CLI_TOOL_TARGET} PRIVATE
        "$<$<CONFIG:Debug>:-g>"
        "$<$<CONFIG:Debug>:-O0>"
        "$<$<CONFIG:Release>:-O3>"
    )
endif()