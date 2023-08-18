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

# Build a AOT library to register quantized ops into PyTorch.
add_library(quantized_ops_aot_lib SHARED
    ${CMAKE_CURRENT_BINARY_DIR}/RegisterCPUCustomOps.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/RegisterSchema.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/CustomOpsNativeFunctions.h
    ${_quantized_kernels__srcs}
)
# Build a library for _quantized_kernels_srcs
#
# quantized_kernels: Pure-C++ kernel library for quantized ops
# `_quantized_kernels__srcs` comes from build/extract_sources.py.
add_library(quantized_kernels ${_quantized_kernels__srcs})
target_link_libraries(quantized_kernels PRIVATE executorch)
target_compile_options(quantized_kernels PUBLIC ${_common_compile_options})
