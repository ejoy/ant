export BX_CONFIG=DEBUG
export BGFX_CONFIG=DEBUG

ifeq "$(PLAT)" "osx"

GENIE=cd bgfx && ../bx/tools/bin/darwin/genie
ifeq ($(shell uname -m), arm64)
OSX_GCC=osx-arm64
else
OSX_GCC=osx
endif

else
GENIE=cd bgfx && ../bx/tools/bin/windows/genie
endif



GENIE_WITH_EDITOR = --with-tools --with-shared-lib --with-dynamic-runtime --with-examples

ifeq "$(PLAT)" "ios"
  BGFX_MAKEFILE = .build/projects/gmake-ios-arm64
else ifeq "$(PLAT)" "osx"

ifeq ($(shell uname -m), arm64)
  BGFX_MAKEFILE = .build/projects/gmake-$(OSX_GCC)
  BGFX_BIN = bgfx/.build/osx-arm64/bin/
else
  BGFX_MAKEFILE = .build/projects/gmake-$(OSX_GCC)
  BGFX_BIN = bgfx/.build/osx64_clang/bin/
endif
  BGFX_SHARED_LIB = libbgfx-shared-lib$(MODE).dylib
else ifeq "$(PLAT)" "mingw"
  BGFX_MAKEFILE = .build/projects/gmake-mingw-gcc
  BGFX_BIN = bgfx/.build/win64_mingw-gcc/bin/
  BGFX_SHARED_LIB = bgfx-shared-lib$(MODE).dll
endif

BGFX_MAKE_CMD = make -R -C bgfx/$(BGFX_MAKEFILE) config=$(MODE)64 -j8 

_bx:
	$(BGFX_MAKE_CMD) bx

_bimg:
	$(BGFX_MAKE_CMD) bimg

_bgfx: bx
	$(BGFX_MAKE_CMD) bgfx

_bimg_decode: _bimg _bx
	$(BGFX_MAKE_CMD) bimg_decode

_bgfx-shared-lib: _bgfx _bimg _bimg_decode
	$(BGFX_MAKE_CMD) bgfx-shared-lib

_tools: _bgfx
	$(BGFX_MAKE_CMD) shaderc texturec

runtime_make: _bx _bimg _bgfx _bimg_decode

TOOLSDIR = ../bin/$(PLAT)/$(MODE)

toolsdir:
	mkdir -p $(TOOLSDIR)

editor_make: runtime_make _bgfx-shared-lib _tools | toolsdir
	cp -f bgfx/src/bgfx_shader.sh ../packages/resources/shaders/bgfx_shader.sh
	cp -f bgfx/src/bgfx_compute.sh ../packages/resources/shaders/bgfx_compute.sh
	cp -f bgfx/examples/common/common.sh ../packages/resources/shaders/common.sh
	cp -f bgfx/examples/common/shaderlib.sh ../packages/resources/shaders/shaderlib.sh
	cp $(BGFX_BIN)shaderc$(MODE) $(TOOLSDIR)/shaderc
	cp $(BGFX_BIN)texturec$(MODE) $(TOOLSDIR)/texturec
	cp $(BGFX_BIN)$(BGFX_SHARED_LIB) $(TOOLSDIR)/bgfx-core.dll

ifeq "$(PLAT)" "msvc"
GENIE_PLATFORM= --with-windows=10.0 vs2019
else ifeq "$(PLAT)" "ios"
GENIE_PLATFORM= --gcc=ios-arm64 gmake
else ifeq "$(PLAT)" "osx"
GENIE_PLATFORM= --gcc=$(OSX_GCC) gmake
else
GENIE_PLATFORM= --os=windows --gcc=mingw-gcc gmake
endif
BGFX_CONFIG=MAX_VIEWS=1024
init:
	export BGFX_CONFIG=$(BGFX_CONFIG) && $(GENIE) $(GENIE_WITH_EDITOR) $(GENIE_PLATFORM)

ifeq "$(PLAT)" "msvc"
make:
	start scripts\bgfx.bat $(MODE)
else ifeq "$(PLAT)" "ios"
make: runtime_make
else
make: editor_make
endif

ifneq "$(PLAT)" "msvc"
clean:
	cd bgfx && make clean
endif
