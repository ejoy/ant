CMAKE_PROJ := ozz-animation reactphysics3d
ALL_PROJ := bgfx $(CMAKE_PROJ)

ifeq "$(PLAT)" ""
	ifeq ($(shell uname), Darwin)
		PLAT = osx
	else
		PLAT = mingw
	endif
endif

ifeq "$(PLAT)" "msvc"
  MODE = debug
else
  MODE = release
endif

ifeq "$(MODE)" "debug"
  CMAKE_BUILD = -DCMAKE_BUILD_TYPE=Debug
else
  CMAKE_BUILD = -DCMAKE_BUILD_TYPE=Release
endif

BUILD_PATH= build
CMAKE_OPT=
CMAKE_PROJ_BUILD_SUB_PATH = $(PLAT)/$(MODE)
CMAKE_PROJ_SRC_RELATIVE_PATH = ../../../..

CMAKE_OPT_ozz-animation=-Dozz_build_samples=OFF -Dozz_build_fbx=OFF -Dozz_build_howtos=OFF -Dozz_build_gltf=ON -Dozz_build_cpp11=ON -DEMSCRIPTEN=FALSE
ifeq "$(PLAT)" "mingw"
TOOL_EXT_NAME=.exe
endif
CMAKE_COPY_ozz-animation= mkdir -p ../../../../../bin/$(PLAT)/$(MODE)/ && cp src/animation/offline/gltf/gltf2ozz$(TOOL_EXT_NAME) ../../../../../bin/$(PLAT)/$(MODE)/gltf2ozz$(TOOL_EXT_NAME)
CMAKE_OPT_reactphysics3d=-DRP3D_LOGS_ENABLED=ON
CMAKE_COPY_reactphysics3d= echo ok

ifeq "$(PLAT)" "osx"
  CMAKE_PROJ_TYPE = Unix Makefiles
else ifeq "$(PLAT)" "ios"
  CMAKE_PROJ_TYPE = Unix Makefiles
  CMAKE_BUILD += -DCMAKE_TOOLCHAIN_FILE=../ios-cmake/ios.toolchain.cmake -DPLATFORM=OS64 -DENABLE_BITCODE=TRUE
else ifeq "$(PLAT)" "msvc"
  CMAKE_PROJ_TYPE = Visual Studio 16 2019
  CMAKE_OPT = -A x64
else
  CMAKE_PROJ_TYPE = MSYS Makefiles
endif


define CMAKE_TEMP
  $(BUILD_PATH)/$(1)/$(CMAKE_PROJ_BUILD_SUB_PATH) :
	mkdir -p $$@

  $(1)_init : | $(BUILD_PATH)/$(1)/$(CMAKE_PROJ_BUILD_SUB_PATH)
	cd $$(BUILD_PATH)/$(1)/$(CMAKE_PROJ_BUILD_SUB_PATH) && cmake $(CMAKE_BUILD) $$(CMAKE_OPT_$(1)) -G "$(CMAKE_PROJ_TYPE)" $(CMAKE_OPT) $(CMAKE_PROJ_SRC_RELATIVE_PATH)/$(1)

ifeq "$(PLAT)" "msvc"
  $(1)_make :
	start scripts\$(1).bat $(MODE)
else
  $(1)_make : | $(BUILD_PATH)/$(1)/$(CMAKE_PROJ_BUILD_SUB_PATH)
	cd $$(BUILD_PATH)/$(1)/$(CMAKE_PROJ_BUILD_SUB_PATH) && make $(MP) && $$(CMAKE_COPY_$(1))

  $(1)_clean : | $(BUILD_PATH)/$(1)/$(CMAKE_PROJ_BUILD_SUB_PATH)
	cd $$(BUILD_PATH)/$(1)/$(CMAKE_PROJ_BUILD_SUB_PATH) && make clean
endif

endef

$(foreach v, $(CMAKE_PROJ), $(eval $(call CMAKE_TEMP,$(v))))

BGFX_MAKE= --no-print-directory -C . -f scripts/bgfx.make MODE=$(MODE) PLAT=$(PLAT)
bgfx_init:
	@${MAKE} $(BGFX_MAKE) init
bgfx_make:
	@${MAKE} $(BGFX_MAKE) make
bgfx_clean:
	@${MAKE} $(BGFX_MAKE) clean

.PHONY: init all clean

init : $(addsuffix _init,$(ALL_PROJ))

ifeq "$(PLAT)" "msvc"
all:
	start make.bat $(MODE)
else
all: $(addsuffix _make,$(ALL_PROJ))
clean: $(addsuffix _clean,$(ALL_PROJ))
endif
