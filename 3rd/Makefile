CMAKE_PROJ := ozz-animation bullet3
RUNTIME_PROJ := ozz-animation bullet3 bgfx
ALL_PROJ := $(RUNTIME_PROJ) $(CMAKE_PROJ)
BUILD_CONFIG = release

ifeq "$(PLAT)" ""
	ifeq ($(shell uname), Darwin)
		PLAT = osx
	else
		PLAT = mingw
	endif
endif

# should add devenv command's path to system path
DEVENV_CMD = devenv

ifeq "$(BUILD_CONFIG)" "release"
  ifeq "$(PLAT)" "ios"
    BGFX_CONFIG_TYPE = release
  else
    BGFX_CONFIG_TYPE = debug
  endif
  CMAKE_BUILD = -DCMAKE_BUILD_TYPE=Release
else
  BGFX_CONFIG_TYPE = debug
  CMAKE_BUILD = -DCMAKE_BUILD_TYPE=Debug
endif

MSVC_MAKE_INFO := @echo msvc not support make single project, use 'make all plat=msvc' instead

BUILD_PATH := build

WIN_SDK = 10.0.16299.0

ifeq "$(PLAT)" "osx"
  CMAKE_PROJ_TYPE = Unix Makefiles
  BGFX_MAKEFILE = .build/projects/gmake-osx
  BGFX_CPRC_CMD = cp bgfx/.build/osx64_clang/bin/shaderc$(BGFX_CONFIG_TYPE) ../clibs/

  CMAKE_PROJ_MAKE = make
  CMAKE_PROJ_CLEAN = make clean
else ifeq "$(PLAT)" "ios"
  CMAKE_PROJ_TYPE = Unix Makefiles
  BGFX_MAKEFILE = .build/projects/gmake-ios-arm64

  CMAKE_PROJ_MAKE = make
  CMAKE_PROJ_CLEAN = make clean

  CMAKE_BUILD += -DCMAKE_TOOLCHAIN_FILE=../ios-cmake/ios.toolchain.cmake -DIOS_PLATFORM=OS64 -DENABLE_BITCODE=TRUE
else ifeq "$(PLAT)" "msvc"
  CMAKE_PROJ_TYPE = Visual Studio 15 2017 Win64

  # only build debug project in msvc
  BGFX_INIT_CMD = ../bx/tools/bin/windows/genie --with-examples --with-tools  --with-dynamic-runtime --with-shared-lib --with-windows=$(WIN_SDK) vs2017
  BGFX_MAKE_CMD = $(MSVC_MAKE_INFO)

  CMAKE_PROJ_MAKE = $(MSVC_MAKE_INFO)
  CMAKE_PROJ_CLEAN = $(MSVC_MAKE_INFO) 
else
  CMAKE_PROJ_TYPE = MSYS Makefiles
  BGFX_MAKEFILE = .build/projects/gmake-mingw-gcc
  BGFX_CPRC_CMD = cp bgfx/.build/win64_mingw-gcc/bin/shaderc$(BGFX_CONFIG_TYPE).exe ../clibs/

  CMAKE_PROJ_MAKE = make
  CMAKE_PROJ_CLEAN = make clean
endif

ifneq "$(PLAT)" "msvc"
BGFX_TARGET = bgfx bimg bx
ifneq "$(BGFX_CPRC_CMD)" ""
BGFX_TARGET += shaderc
endif
BGFX_INIT_CMD = make $(BGFX_MAKEFILE)
BGFX_MAKE_CMD = make -R -C $(BGFX_MAKEFILE) config=$(BGFX_CONFIG_TYPE)64 -j8 $(BGFX_TARGET)
endif

# ASSIMP_FMT_NAMES := AMF 3DS AC ASE ASSBIN ASSXML B3D BVH COLLADA DXF CSM IRR LWO LWS MD2 MD3 MD5 MDC NFF NDO OFF OBJ OGRE OPENGEX PLY MS3D COB BLEND IFC XGL Q3D Q3BSP RAW SIB SMD STL TERRAGEN 3D X X3D GLTF 3MF MMD HMP MDL
# #ASSIMP_FMT_NAMES := IFC
# ASSIMP_IMPORT_DISABLE_OPT := $(patsubst %,-DASSIMP_BUILD_%_IMPORTER=OFF,$(ASSIMP_FMT_NAMES))

# CMAKE_OPT_assimp :=$(ASSIMP_IMPORT_DISABLE_OPT) -DBUILD_SHARED_LIBS=OFF -DASSIMP_BUILD_TESTS=OFF
CMAKE_OPT_freetype :=-DCMAKE_DISABLE_FIND_PACKAGE_BZip2=TRUE -DCMAKE_DISABLE_FIND_PACKAGE_ZLIB=TRUE
# disable build bullet demos and tests

CMAKE_OPT_bullet3 = -DBUILD_BULLET2_DEMOS=OFF -DBUILD_UNIT_TESTS=OFF -DBUILD_EXTRAS=OFF

WITH_OZZ_SAMPLES := OFF
OZZ_ENABLE_EMSCRIPTEN := FALSE

ifeq "$(PLAT)" "mingw"
  CMAKE_OPT_bullet3 += -DLIBRARY_OUTPUT_PATH=../../../build/bullet3/$(PLAT)/lib
else ifeq "$(PLAT)" "msvc"
  CMAKE_OPT_bullet3 += -DUSE_MSVC_RUNTIME_LIBRARY_DLL=ON -DLIBRARY_OUTPUT_PATH=../../../build/bullet3/$(PLAT)/lib -DBUILD_BULLET2_DEMOS=ON
  WITH_OZZ_SAMPLES := ON
else ifeq "$(PLAT)" "ios"
  OZZ_ENABLE_EMSCRIPTEN := TRUE
else
  CMAKE_OPT_bullet3 += -DLIBRARY_OUTPUT_PATH=../../lib
endif

CMAKE_OPT_ozz-animation=-Dozz_build_samples=$(WITH_OZZ_SAMPLES) -Dozz_build_fbx=$(WITH_OZZ_SAMPLES) -Dozz_build_howtos=$(WITH_OZZ_SAMPLES) -DEMSCRIPTEN=$(OZZ_ENABLE_EMSCRIPTEN)

.PHONY: info init all clean

info :
	@echo Please do 'make init' or 'make init msvc=on' for the first time , and then 'make all' or 'make all msvc=on' . when msvc=on is passed, it not support the make single project, like 'make bgfx_make msvc=on'

ifeq "$(PLAT)" "ios"
init : $(addsuffix _init,$(RUNTIME_PROJ))
else
init : $(addsuffix _init,$(ALL_PROJ))
endif

ifeq "$(PLAT)" "msvc"
  MAKE_ALL_DEPEND = msvc_all
else
  MAKE_ALL_DEPEND = $(addsuffix _make,$(ALL_PROJ))
endif

all : $(MAKE_ALL_DEPEND)

runtime : $(addsuffix _make,$(RUNTIME_PROJ))

msvc_all : 
	start build_msvc_all.bat

clean : $(addsuffix _clean,$(ALL_PROJ))

# $(BUILD_PATH) :
# 	mkdir $@

# $(BUILD_PATH)/bgfx : | $(BUILD_PATH)

$(BUILD_PATH):
	mkdir $@

bgfx_init : | $(BUILD_PATH)
	cd bgfx && $(BGFX_INIT_CMD)
bgfx_make : | $(BUILD_PATH)
	cd bgfx && $(BGFX_MAKE_CMD)
	$(BGFX_CPRC_CMD)
bgfx_clean :
	cd bgfx && make clean

define CMAKE_TEMP
  $(BUILD_PATH)/$(1)/$(PLAT) : | $(BUILD_PATH)
	mkdir -p $$@

  $(1)_init : | $(BUILD_PATH)/$(1)/$(PLAT)
	cd $$(BUILD_PATH)/$(1)/$(PLAT) && cmake $(CMAKE_BUILD) $$(CMAKE_OPT_$(1)) -G "$(CMAKE_PROJ_TYPE)" ../../../$(1)

  $(1)_make : | $(BUILD_PATH)/$(1)/$(PLAT)
	cd $$(BUILD_PATH)/$(1)/$(PLAT) && make $(MP)

  $(1)_clean : | $(BUILD_PATH)/$(1)/$(PLAT)
	cd $$(BUILD_PATH)/$(1)/$(PLAT) && make clean
endef

$(foreach v, $(CMAKE_PROJ), $(eval $(call CMAKE_TEMP,$(v))))
#$(foreach v, $(CMAKE_PROJ), $(warning $(call CMAKE_TEMP,$(v))))
