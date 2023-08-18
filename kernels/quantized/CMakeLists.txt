# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

# Kernel library for quantized operators. Please this file formatted by running:
# ~~~
# cmake-format --first-comment-is-literal=True CMakeLists.txt
# ~~~
cmake_minimum_required(VERSION 3.19)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 17)
endif()

if(NOT PYTHON_EXECUTABLE)
  set(PYTHON_EXECUTABLE python3)
endif()
# Source root directory for executorch.
if(NOT EXECUTORCH_ROOT)
  set(EXECUTORCH_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../..)
endif()
# Source root directory for pytorch.
if(NOT TORCH_ROOT)
  set(TORCH_ROOT ${EXECUTORCH_ROOT}/third-party/pytorch)
endif()

set(_common_compile_options -Wno-deprecated-declarations)

include(${EXECUTORCH_ROOT}/build/Utils.cmake)
include(${EXECUTORCH_ROOT}/build/Codegen.cmake)
# Quantized ops kernel sources
file(GLOB_RECURSE _quantized_kernels__srcs
        "${CMAKE_CURRENT_SOURCE_DIR}/cpu/*.cpp")
# Generate C++ bindings to register kernels into both PyTorch (for AOT) and
# Executorch (for runtime). Here select all ops in quantized.yaml
gen_selected_ops("${CMAKE_CURRENT_LIST_DIR}/quantized.yaml" "" "")
# Expect gen_selected_ops output file to be selected_operators.yaml
generate_bindings_for_kernels("" ${CMAKE_CURRENT_SOURCE_DIR}/quantized.yaml)
message("Generated files ${gen_command_sources}")

# Build a AOT library to register quantized ops into PyTorch.
add_library(
        quantized_ops_aot_lib SHARED
        ${CMAKE_CURRENT_BINARY_DIR}/RegisterCPUCustomOps.cpp
        ${CMAKE_CURRENT_BINARY_DIR}/RegisterSchema.cpp
        ${CMAKE_CURRENT_BINARY_DIR}/CustomOpsNativeFunctions.h
        ${_quantized_kernels__srcs}
        ${EXECUTORCH_ROOT}/runtime/core/exec_aten/util/tensor_util_aten.cpp # This is a
        # hack
)
# Find `Torch`.
find_package(Torch REQUIRED)
target_compile_definitions(quantized_ops_aot_lib PRIVATE USE_ATEN_LIB=1)
target_include_directories(quantized_ops_aot_lib
        PUBLIC ${_common_include_directories})
include_directories(${TORCH_INCLUDE_DIRS})

target_link_libraries(quantized_ops_aot_lib PRIVATE torch executorch)
# Ensure that the load-time constructor functions run. By default, the linker
# would remove them since there are no other references to them.
if(APPLE)
  macos_kernel_link_options(quantized_ops_aot_lib)
else()
  kernel_link_options(quantized_ops_aot_lib)
endif()

# Build a library for _quantized_kernels_srcs
#
# quantized_kernels: Pure-C++ kernel library for quantized ops
add_library(quantized_kernels ${_quantized_kernels__srcs})
target_link_libraries(quantized_kernels PRIVATE executorch)
target_compile_options(quantized_kernels PUBLIC ${_common_compile_options})
# Ensure that the load-time constructor functions run. By default, the linker
# would remove them since there are no other references to them.
if(APPLE)
  macos_kernel_link_options(quantized_kernels)
else()
  kernel_link_options(quantized_kernels)
endif()
