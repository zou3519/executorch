# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

# Example CMakeLists.txt for registering custom ops into Executorch. In this
# example we have custom ops `my_ops::mul3.out` implemented in C++ in
# `examples/custom_ops/custom_ops_1.cpp`. We also have it registered into EXIR
# in `examples/custom_ops/custom_ops_1.py`. This CMakeLists.txt runs a script to
# generate wrapper code based on the operator-kernel binding defined in
# `examples/custom_ops/custom_ops.yaml`. Then creates a library that contains
# both binding wrapper and the implementation source file. This library can be
# linked into Executorch binary (`executor_runner` in this example) and it is
# ready to run models containing that custom op.
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

include(${EXECUTORCH_ROOT}/build/Utils.cmake)

# Generate C++ bindings to register kernels into both PyTorch (for AOT) and Executorch (for runtime).
if(REGISTER_EXAMPLE_CUSTOM_OP EQUAL 1)
  generate_bindings_for_kernels("my_ops::mul3.out" "")
elseif(REGISTER_EXAMPLE_CUSTOM_OP EQUAL 2)
  generate_bindings_for_kernels("my_ops::mul4.out" "")
endif()
# Prepare for C++ libraries.

# C++ library to register custom ops into PyTorch.
if(REGISTER_EXAMPLE_CUSTOM_OP EQUAL 2)
  add_library(
    custom_ops_aot_lib SHARED
    ${CMAKE_CURRENT_BINARY_DIR}/RegisterCPUCustomOps.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/RegisterSchema.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/CustomOpsNativeFunctions.h
    ${CMAKE_CURRENT_LIST_DIR}/custom_ops_2.cpp # register my_ops::mul4
    ${CMAKE_CURRENT_LIST_DIR}/custom_ops_2_out.cpp # register my_ops::mul4.out
  )
  # Find `Torch`.
  find_package(Torch REQUIRED)
  # ATen mode is on
  target_compile_definitions(custom_ops_aot_lib PRIVATE USE_ATEN_LIB=1)
  target_include_directories(custom_ops_aot_lib
                             PUBLIC ${_common_include_directories})
  include_directories(${TORCH_INCLUDE_DIRS})

  target_link_libraries(custom_ops_aot_lib PRIVATE torch executorch)

  # Ensure that the load-time constructor functions run. By default, the linker
  # would remove them since there are no other references to them.
  if(APPLE)
    macos_kernel_link_options("custom_ops_aot_lib")
  else()
    kernel_link_options("custom_ops_aot_lib")
  endif()
endif()

# C++ library to register custom ops into Executorch runtime.
add_library(custom_ops_lib)
target_sources(
  custom_ops_lib
  PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR}/RegisterCodegenUnboxedKernelsEverything.cpp
    ${CMAKE_CURRENT_BINARY_DIR}/Functions.h
    ${CMAKE_CURRENT_BINARY_DIR}/NativeFunctions.h
    ${CMAKE_CURRENT_BINARY_DIR}/CustomOpsNativeFunctions.h)
if(REGISTER_EXAMPLE_CUSTOM_OP EQUAL 1)
  target_sources(custom_ops_lib
                 PRIVATE ${CMAKE_CURRENT_LIST_DIR}/custom_ops_1_out.cpp)
elseif(REGISTER_EXAMPLE_CUSTOM_OP EQUAL 2)
  target_sources(custom_ops_lib
                 PRIVATE ${CMAKE_CURRENT_LIST_DIR}/custom_ops_2_out.cpp)
endif()

target_link_libraries(custom_ops_lib PRIVATE executorch)

# Ensure that the load-time constructor functions run. By default, the linker
# would remove them since there are no other references to them.
if(APPLE)
  macos_kernel_link_options(custom_ops_lib)
else()
  kernel_link_options(custom_ops_lib)
endif()
