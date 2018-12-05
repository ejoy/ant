CMAKE_PROJ = assimp freetype ozz-animation bullet3
RUNTIME_PROJ = freetype ozz-animation bullet3 bgfx zlib
ALL_PROJ = $(RUNTIME_PROJ) assimp cd cjson
BUILD_CONFIG = release

# should add devenv command's path to system path
DEVENV_CMD = devenv

ifeq "$(BUILD_CONFIG)" "release"
  BGFX_CONFIG_TYPE = release
  CMAKE_BUILD = -DCMAKE_BUILD_TYPE=Release
else
  BGFX_CONFIG_TYPE = debug
  CMAKE_BUILD = -DCMAKE_BUILD_TYPE=Debug
endif

MSVC_MAKE_INFO := @echo msvc not support make single project, use 'make all plat=msvc' instead

ifeq "$(PLAT)" "osx"
  CMAKE_PROJ_TYPE = Unix Makefiles
  BUILD_PATH := build
  BGFX_INIT_CMD = make .build/projects/gmake-osx
  BGFX_MAKE_CMD = make osx-$(BGFX_CONFIG_TYPE)64 $(MP)
  
  CD_MAKE_CMD	= TEC_UNAME=clang make cd $(MP)

  CMAKE_PROJ_MAKE = make
  CMAKE_PROJ_CLEAN = make clean
else ifeq "$(PLAT)" "ios"
  CMAKE_PROJ_TYPE = Unix Makefiles
  BUILD_PATH := build
  BGFX_INIT_CMD = make .build/projects/gmake-ios-arm64
  BGFX_MAKE_CMD = make ios-arm64-$(BGFX_CONFIG_TYPE) $(MP)
  
  CD_MAKE_CMD	= TEC_UNAME=clang make cd $(MP)

  CMAKE_PROJ_MAKE = make
  CMAKE_PROJ_CLEAN = make clean

  CMAKE_BUILD += -DCMAKE_TOOLCHAIN_FILE=../ios-cmake/ios.toolchain.cmake -DIOS_PLATFORM=OS64 -DENABLE_BITCODE=TRUE
else ifeq "$(PLAT)" "msvc"
  CMAKE_PROJ_TYPE = Visual Studio 15 2017 Win64
  BUILD_PATH := build_msvc

  # only build debug project in msvc
  BGFX_INIT_CMD = ../bx/tools/bin/windows/genie --with-examples --with-tools  --with-dynamic-runtime --with-shared-lib --with-windows=10.0.16299.0 vs2017
  BGFX_MAKE_CMD = $(MSVC_MAKE_INFO)

  #cd lib only support Debug configuration
  CD_MAKE_CMD = $(MSVC_MAKE_INFO)

  CMAKE_PROJ_MAKE = $(MSVC_MAKE_INFO)
  CMAKE_PROJ_CLEAN = $(MSVC_MAKE_INFO) 
else
  CMAKE_PROJ_TYPE = MSYS Makefiles
  BUILD_PATH := build
  BGFX_INIT_CMD = make .build/projects/gmake-mingw-gcc
  BGFX_MAKE_CMD = make mingw-gcc-$(BGFX_CONFIG_TYPE)64 $(MP)
  
  CD_MAKE_CMD	= TEC_UNAME=mingw6_64 MINGW6_64=$(MINGW) make cd $(MP)

  CMAKE_PROJ_MAKE = make
  CMAKE_PROJ_CLEAN = make clean   
endif

ASSIMP_FMT_NAMES := AMF 3DS AC ASE ASSBIN ASSXML B3D BVH COLLADA DXF CSM IRR LWO LWS MD2 MD3 MD5 MDC NFF NDO OFF OBJ OGRE OPENGEX PLY MS3D COB BLEND IFC XGL Q3D Q3BSP RAW SIB SMD STL TERRAGEN 3D X X3D GLTF 3MF MMD HMP MDL
ASSIMP_IMPORT_DISABLE_OPT := $(patsubst %,-DASSIMP_BUILD_%_IMPORTER=OFF,$(ASSIMP_FMT_NAMES))

CMAKE_OPT_assimp :=$(ASSIMP_IMPORT_DISABLE_OPT) -DBUILD_SHARED_LIBS=OFF -DASSIMP_BUILD_TESTS=OFF
CMAKE_OPT_freetype :=-DCMAKE_DISABLE_FIND_PACKAGE_BZip2=TRUE -DCMAKE_DISABLE_FIND_PACKAGE_ZLIB=TRUE
# disable build bullet demos and tests

CMAKE_OPT_bullet3 = -DBUILD_BULLET2_DEMOS=OFF -DBUILD_UNIT_TESTS=OFF -DBUILD_EXTRAS=OFF

ifeq "$(PLAT)" "msvc"
  CMAKE_OPT_bullet3 += -DUSE_MSVC_RUNTIME_LIBRARY_DLL=ON
else
  CMAKE_OPT_bullet3 += -DLIBRARY_OUTPUT_PATH=../../lib
endif

CMAKE_OPT_ozz-animation=-Dozz_build_samples=OFF -Dozz_build_fbx=OFF -Dozz_build_howtos=OFF

ifeq "$(PLAT)" "ios"
CMAKE_OPT_ozz-animation += -DEMSCRIPTEN=TURE
endif

.PHONY: info init all clean

info :
	@echo Please do 'make init' or 'make init msvc=on' for the first time , and then 'make all' or 'make all msvc=on' . when msvc=on is passed, it not support the make single project, like 'make bgfx_make msvc=on'

init : $(addsuffix _init,$(ALL_PROJ))

ifeq "$(msvc)" ""
  MAKE_ALL_DEPEND = $(addsuffix _make,$(ALL_PROJ))
else
  MAKE_ALL_DEPEND = msvc_all
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
bgfx_clean :
	cd bgfx && make clean

cd_init : | $(BUILD_PATH)
cd_make : | $(BUILD_PATH)
	cd cd && $(CD_MAKE_CMD)
cd_clean:
	cd cd && make clean

cjson_init: | $(BUILD_PATH)
cjson_make: | $(BUILD_PATH)
	cd lua-cjson && make TARGET=cjson.dll LUA_INCLUDE_DIR=../../clibs/lua CJSON_CFLAGS=-DDISABLE_INVALID_NUMBERS CJSON_LDFLAGS="-shared -L../../clibs/lua -llua53" LUA_BIN_SUFFIX=.lua
cjson_clean:
	cd lua-cjson && make clean TARGET=cjson.dll

zlib_init: | $(BUILD_PATH)
	cd zlib && ./configure
zlib_make: | $(BUILD_PATH)
	cd zlib && make
zlib_clean:
	cd zlib && make clean

define CMAKE_TEMP
  $(BUILD_PATH)/$(1) : | $(BUILD_PATH)
	mkdir $$@

  $(1)_init : | $(BUILD_PATH)/$(1)
	cd $$(BUILD_PATH)/$(1) && cmake $(CMAKE_BUILD) $$(CMAKE_OPT_$(1)) -G "$(CMAKE_PROJ_TYPE)" ../../$(1)

  $(1)_make : | $(BUILD_PATH)/$(1)
	cd $$(BUILD_PATH)/$(1) && make $(MP)

  $(1)_clean : | $(BUILD_PATH)/$(1)
	cd $$(BUILD_PATH)/$(1) && make clean
endef

$(foreach v, $(CMAKE_PROJ), $(eval $(call CMAKE_TEMP,$(v))))
#$(foreach v, $(CMAKE_PROJ), $(warning $(call CMAKE_TEMP,$(v))))
