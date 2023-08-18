# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

# This file is intended to have helper functions to keep the CMakeLists.txt concise. If there are any helper function can be re-used, it's recommented to add them here.


# Public function to print summary for all configurations. For new variable, it's recommended to add them here.
function(executorch_print_configuration_summary)
    message(STATUS "")
    message(STATUS "******** Summary ********")
    message(STATUS "  BUCK                          : ${BUCK2}")
    message(STATUS "  CMAKE_CXX_STANDARD            : ${CMAKE_CXX_STANDARD}")
    message(STATUS "  CMAKE_CXX_COMPILER_ID         : ${CMAKE_CXX_COMPILER_ID}")
    message(STATUS "  CMAKE_TOOLCHAIN_FILE          : ${CMAKE_TOOLCHAIN_FILE}")
    message(STATUS "  FLATBUFFERS_BUILD_FLATC       : ${FLATBUFFERS_BUILD_FLATC}")
    message(STATUS "  FLATBUFFERS_BUILD_FLATHASH    : ${FLATBUFFERS_BUILD_FLATHASH}")
    message(STATUS "  FLATBUFFERS_BUILD_FLATLIB     : ${FLATBUFFERS_BUILD_FLATLIB}")
    message(STATUS "  FLATBUFFERS_BUILD_TESTS       : ${FLATBUFFERS_BUILD_TESTS}")
    message(STATUS "  REGISTER_EXAMPLE_CUSTOM_OPS   : ${REGISTER_EXAMPLE_CUSTOM_OPS}")
endfunction()

# This is the funtion to use -Wl, --whole-archive to link static library
function(kernel_link_options target_name)
    target_link_options(${target_name}
        INTERFACE
        # TODO(dbort): This will cause the .a to show up on the link line twice
        -Wl,--whole-archive
        $<TARGET_FILE:${target_name}>
        -Wl,--no-whole-archive
    )
endfunction()

function(macos_kernel_link_options target_name)
    target_link_options(${target_name}
        INTERFACE
        # Same as kernel_link_options but it's for MacOS linker
        -Wl,-force_load,$<TARGET_FILE:${target_name}>
    )
endfunction()

function(generate_bindings_for_kernels root_ops include_all_ops)
    # Command to generate selected_operators.yaml from custom_ops.yaml.
    set(_oplist_yaml ${CMAKE_CURRENT_BINARY_DIR}/selected_operators.yaml)
    file(GLOB_RECURSE _codegen_tools_srcs "${EXECUTORCH_ROOT}/codegen/tools/*.py")
    file(GLOB_RECURSE _codegen_templates "${EXECUTORCH_ROOT}/codegen/templates/*")
    file(GLOB_RECURSE _torchgen_srcs "${TORCH_ROOT}/torchgen/*.py")

    # Selective build. If we want to register all ops in custom_ops.yaml, do
    # `--ops_schema_yaml_path=${CMAKE_CURRENT_LIST_DIR}/custom_ops.yaml)` instead of
    # `root_ops`
    set(_gen_oplist_command "${PYTHON_EXECUTABLE}" -m codegen.tools.gen_oplist
                            --output_path=${_oplist_yaml})
    message("all arguments: ${ARGV}")

    if(include_all_ops)
        message("Here")
        list(APPEND _gen_oplist_command --include-all-operators)
    elseif(root_ops)
        message("There")
        list(APPEND _gen_oplist_command --root_ops="${root_ops}")
    endif()

    # Command to codegen C++ wrappers to register custom ops to both PyTorch and
    # Executorch runtime.
    set(_gen_command
        "${PYTHON_EXECUTABLE}" -m torchgen.gen_executorch
        --source-path=${EXECUTORCH_ROOT}/codegen
        --install-dir=${CMAKE_CURRENT_BINARY_DIR}
        --tags-path=${TORCH_ROOT}/aten/src/ATen/native/tags.yaml
        --aten-yaml-path=${TORCH_ROOT}/aten/src/ATen/native/native_functions.yaml
        --op-selection-yaml-path=${_oplist_yaml}
        --custom-ops-yaml-path=${CMAKE_CURRENT_LIST_DIR}/custom_ops.yaml)

    set(_gen_command_sources
        ${CMAKE_CURRENT_BINARY_DIR}/RegisterCodegenUnboxedKernelsEverything.cpp
        ${CMAKE_CURRENT_BINARY_DIR}/RegisterCPUCustomOps.cpp
        ${CMAKE_CURRENT_BINARY_DIR}/RegisterSchema.cpp
        ${CMAKE_CURRENT_BINARY_DIR}/Functions.h
        ${CMAKE_CURRENT_BINARY_DIR}/NativeFunctions.h
        ${CMAKE_CURRENT_BINARY_DIR}/CustomOpsNativeFunctions.h)
    message(STATUS "Generating selected operator list ${_gen_oplist_command}")

    add_custom_command(
        COMMENT "Generating selected_operators.yaml for custom ops"
        OUTPUT ${_oplist_yaml}
        COMMAND ${_gen_oplist_command}
        DEPENDS ${CMAKE_CURRENT_LIST_DIR}/custom_ops.yaml ${_codegen_tools_srcs}
        WORKING_DIRECTORY ${EXECUTORCH_ROOT})

    add_custom_command(
        COMMENT "Generating code for custom operator registration"
        OUTPUT ${_gen_command_sources}
        COMMAND ${_gen_command}
        DEPENDS ${_oplist_yaml} ${CMAKE_CURRENT_LIST_DIR}/custom_ops.yaml
                ${_codegen_templates} ${_torchgen_srcs}
        WORKING_DIRECTORY ${EXECUTORCH_ROOT})
endfunction()