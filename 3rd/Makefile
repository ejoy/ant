CMAKE_PROJ := ozz-animation bullet3
ALL_PROJ := bgfx $(CMAKE_PROJ)
MODE = release

ifeq "$(PLAT)" ""
	ifeq ($(shell uname), Darwin)
		PLAT = osx
	else
		PLAT = mingw
	endif
endif

ifeq "$(MODE)" "debug"
  CMAKE_BUILD = -DCMAKE_BUILD_TYPE=Debug
else
  CMAKE_BUILD = -DCMAKE_BUILD_TYPE=Release
endif

MSVC_MAKE_INFO := @echo msvc not support make single project, use 'make all plat=msvc' instead

BUILD_PATH := build

WIN_SDK = 10.0
MSVC_VERSION = vs2019

CMAKE_OPT = 

ifeq "$(PLAT)" "osx"
  CMAKE_PROJ_TYPE = Unix Makefiles
  BGFX_MAKEFILE = .build/projects/gmake-osx
  BGFX_CPRC_CMD = cd .build/osx64_clang/bin/
  BGFX_SHARED_LIB = libbgfx-shared-lib$(MODE).dylib

  CMAKE_PROJ_MAKE = make
  CMAKE_PROJ_CLEAN = make clean
else ifeq "$(PLAT)" "ios"
  CMAKE_PROJ_TYPE = Unix Makefiles
  BGFX_MAKEFILE = .build/projects/gmake-ios-arm64

  CMAKE_PROJ_MAKE = make
  CMAKE_PROJ_CLEAN = make clean

  CMAKE_BUILD += -DCMAKE_TOOLCHAIN_FILE=../ios-cmake/ios.toolchain.cmake -DPLATFORM=OS64 -DENABLE_BITCODE=TRUE
else ifeq "$(PLAT)" "msvc"
  ifeq "$(MSVC_VERSION)" "vs2019"
    CMAKE_PROJ_TYPE = Visual Studio 16 2019
    CMAKE_OPT = -A x64
  else
    CMAKE_PROJ_TYPE = Visual Studio 15 2017 Win64
  endif  

  # only build debug project in msvc
  BGFX_INIT_CMD = ../bx/tools/bin/windows/genie --with-examples --with-tools  --with-dynamic-runtime --with-shared-lib --with-windows=$(WIN_SDK) $(MSVC_VERSION)
  BGFX_MAKE_CMD = $(MSVC_MAKE_INFO)

  CMAKE_PROJ_MAKE = $(MSVC_MAKE_INFO)
  CMAKE_PROJ_CLEAN = $(MSVC_MAKE_INFO)
else
  CMAKE_PROJ_TYPE = MSYS Makefiles
  BGFX_MAKEFILE = .build/projects/gmake-mingw-gcc
  BGFX_CPRC_CMD = cd .build/win64_mingw-gcc/bin/
  BGFX_SHARED_LIB = bgfx-shared-lib$(MODE).dll

  CMAKE_PROJ_MAKE = make
  CMAKE_PROJ_CLEAN = make clean
endif

SHADER_SRC_PATH = ../../packages/resources/shaders

ifneq "$(PLAT)" "msvc"
BGFX_TARGET_A = bgfx
BGFX_TARGET_B = bimg bx
ifeq "$(BGFX_CPRC_CMD)" ""
  BGFX_CPRC_CMD += echo ok
  COPY_SHADER_FILES_CMD += echo ok
else
  BGFX_TARGET_A += bgfx-shared-lib
  BGFX_TARGET_B += shaderc texturec
  BGFX_CPRC_CMD += && cp shaderc$(MODE) ../../../../../clibs/
  BGFX_CPRC_CMD += && cp texturec$(MODE) ../../../../../clibs/
  BGFX_CPRC_CMD += && cp $(BGFX_SHARED_LIB) ../../../../../clibs/bgfx-core.dll

  COPY_SHADER_FILES_CMD = cp -f src/bgfx_shader.sh $(SHADER_SRC_PATH)/bgfx_shader.sh
  COPY_SHADER_FILES_CMD += && cp -f src/bgfx_compute.sh $(SHADER_SRC_PATH)/bgfx_compute.sh
  COPY_SHADER_FILES_CMD += && cp -f examples/common/common.sh $(SHADER_SRC_PATH)/common.sh
  COPY_SHADER_FILES_CMD += && cp -f examples/common/shaderlib.sh $(SHADER_SRC_PATH)/shaderlib.sh
endif
BGFX_INIT_CMD = make $(BGFX_MAKEFILE)
BGFX_MAKE_CMD = make -R -C $(BGFX_MAKEFILE) config=$(MODE)64 -j8
else
COPY_SHADER_FILES_CMD += echo ok
endif

CMAKE_OPT_bullet3 = -DBUILD_BULLET2_DEMOS=OFF -DBUILD_UNIT_TESTS=OFF -DBUILD_EXTRAS=OFF

WITH_OZZ_SAMPLES := OFF
OZZ_ENABLE_EMSCRIPTEN := FALSE

ifeq "$(PLAT)" "mingw"
  CMAKE_OPT_bullet3 += -DLIBRARY_OUTPUT_PATH=../../../../build/bullet3/$(PLAT)/$(MODE)/lib
else ifeq "$(PLAT)" "msvc"
  CMAKE_OPT_bullet3 += -DUSE_MSVC_RUNTIME_LIBRARY_DLL=ON -DLIBRARY_OUTPUT_PATH=../../../../build/bullet3/$(PLAT)/$(MODE)/lib -DBUILD_BULLET2_DEMOS=ON
  WITH_OZZ_SAMPLES := ON
else ifeq "$(PLAT)" "ios"
  OZZ_ENABLE_EMSCRIPTEN := TRUE
  CMAKE_OPT_bullet3 += -DLIBRARY_OUTPUT_PATH=../../lib
else
  CMAKE_OPT_bullet3 += -DLIBRARY_OUTPUT_PATH=../../lib
endif

CMAKE_OPT_ozz-animation=-Dozz_build_samples=$(WITH_OZZ_SAMPLES) -Dozz_build_fbx=$(WITH_OZZ_SAMPLES) -Dozz_build_howtos=$(WITH_OZZ_SAMPLES) -DEMSCRIPTEN=$(OZZ_ENABLE_EMSCRIPTEN)

.PHONY: info init all clean

info :
	@echo Please do 'make init' or 'make init msvc=on' for the first time , and then 'make all' or 'make all msvc=on' . when msvc=on is passed, it not support the make single project, like 'make bgfx_make msvc=on'

init : $(addsuffix _init,$(ALL_PROJ))

ifeq "$(PLAT)" "msvc"
  MAKE_ALL_DEPEND = msvc_all
else
  MAKE_ALL_DEPEND = $(addsuffix _make,$(ALL_PROJ))
endif

all : $(MAKE_ALL_DEPEND)

msvc_all : 
	start build_msvc_all.bat

clean : $(addsuffix _clean,$(ALL_PROJ))


$(BUILD_PATH):
	mkdir $@

bgfx_init : | $(BUILD_PATH)
	cd bgfx && $(BGFX_INIT_CMD) && $(COPY_SHADER_FILES_CMD)
bgfx_make : | $(BUILD_PATH)
	cd bgfx && $(BGFX_MAKE_CMD) $(BGFX_TARGET_A) CFLAGS=-DBGFX_CONFIG_DEBUG=1 && $(BGFX_MAKE_CMD) $(BGFX_TARGET_B) && $(BGFX_CPRC_CMD)
bgfx_clean :
	cd bgfx && make clean


ifeq "$(PLAT)" "msvc"
CMAKE_PROJ_BUILD_SUB_PATH = $(PLAT)
CMAKE_PROJ_SRC_RELATIVE_PATH = ../../..
else
CMAKE_PROJ_BUILD_SUB_PATH = $(PLAT)/$(MODE)
CMAKE_PROJ_SRC_RELATIVE_PATH = ../../../..
endif

define CMAKE_TEMP
  $(BUILD_PATH)/$(1)/$(CMAKE_PROJ_BUILD_SUB_PATH) : | $(BUILD_PATH)
	mkdir -p $$@

  $(1)_init : | $(BUILD_PATH)/$(1)/$(CMAKE_PROJ_BUILD_SUB_PATH)
	cd $$(BUILD_PATH)/$(1)/$(CMAKE_PROJ_BUILD_SUB_PATH) && cmake $(CMAKE_BUILD) $$(CMAKE_OPT_$(1)) -G "$(CMAKE_PROJ_TYPE)" $(CMAKE_OPT) $(CMAKE_PROJ_SRC_RELATIVE_PATH)/$(1)

  $(1)_make : | $(BUILD_PATH)/$(1)/$(CMAKE_PROJ_BUILD_SUB_PATH)
	cd $$(BUILD_PATH)/$(1)/$(CMAKE_PROJ_BUILD_SUB_PATH) && make $(MP)

  $(1)_clean : | $(BUILD_PATH)/$(1)/$(CMAKE_PROJ_BUILD_SUB_PATH)
	cd $$(BUILD_PATH)/$(1)/$(CMAKE_PROJ_BUILD_SUB_PATH) && make clean
endef

$(foreach v, $(CMAKE_PROJ), $(eval $(call CMAKE_TEMP,$(v))))
#$(foreach v, $(CMAKE_PROJ), $(warning $(call CMAKE_TEMP,$(v))))
