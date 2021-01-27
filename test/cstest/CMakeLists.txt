cmake_minimum_required(VERSION 3.7)
project(cstest CXX)

set(3RD_DIR "${CMAKE_SOURCE_DIR}/../../3rd")
set(BGFX_DIR "${3RD_DIR}/bgfx")
set(BX_DIR "${3RD_DIR}/bx")
set(BIMG_DIR "${3RD_DIR}/bimg")
set(BGFX_BUILD_DIR "${BGFX_DIR}/.build")

message(STATUS "3RD_DIR:    ${3RD_DIR}")
message(STATUS "BGFX_DIR:   ${BGFX_DIR}")
message(STATUS "BX_DIR:     ${BX_DIR}")
message(STATUS "BIMG_DIR:   ${BIMG_DIR}")

if(WIN32)
    set(BGFX_BUILD_PROJ_NAME "win64_vs2019")
    set(BX_COMPAT_DIR "${BX_DIR}/include/compat/msvc")
endif()

if ("${CMAKE_BUILD_TYPE}" STREQUAL "")
    set(CMAKE_BUILD_TYPE "Debug")
endif()

set(BGFX_LIB_NAMES 
    "bgfx${CMAKE_BUILD_TYPE}.lib"
    "bx${CMAKE_BUILD_TYPE}.lib"
    "bimg${CMAKE_BUILD_TYPE}.lib"
    "bimg_decode${CMAKE_BUILD_TYPE}.lib"
    "example-common${CMAKE_BUILD_TYPE}.lib"
    "example-glue${CMAKE_BUILD_TYPE}.lib"
    
)

# foreach (n in ${BGFX_LIB_NAMES})
#     list(APPEND BGFX_LIBS "${BGFX_BUILD_DIR}/${BGFX_BUILD_PROJ_NAME}/${n}")
# endforeach()

add_executable(cstest cstest.cpp)

set_property(TARGET cstest PROPERTY CXX_STANDARD 17)

target_compile_definitions(cstest PUBLIC _CRT_SECURE_NO_WARNINGS)
target_link_directories(cstest PUBLIC 
    "${BGFX_BUILD_DIR}/${BGFX_BUILD_PROJ_NAME}/bin"
)

target_include_directories(cstest PUBLIC
    "${BGFX_DIR}/include"
    "${BGFX_DIR}/examples/common"
    "${BGFX_DIR}/3rdparty"
    "${BX_DIR}/include"
    "${BX_COMPAT_DIR}"
    "${BIMG_DIR}/include"
    )
message(STATUS "BGFX_LIBS:${BGFX_LIBS}")
target_link_libraries(cstest ${BGFX_LIB_NAMES})



