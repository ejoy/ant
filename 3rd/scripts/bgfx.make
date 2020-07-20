export BX_CONFIG=DEBUG
export BGFX_CONFIG=DEBUG

ifeq ($(shell uname), Darwin)
GENIE=cd bgfx && ../bx/tools/bin/darwin/genie
else
GENIE=cd bgfx && ../bx/tools/bin/windows/genie
endif
GENIE_WITH_EDITOR = --with-tools --with-shared-lib --with-dynamic-runtime

ifeq "$(PLAT)" "ios"
  BGFX_MAKEFILE = .build/projects/gmake-ios-arm64
else ifeq "$(PLAT)" "osx"
  BGFX_MAKEFILE = .build/projects/gmake-osx
  BGFX_BIN = bgfx/.build/osx64_clang/bin/
  BGFX_SHARED_LIB = libbgfx-shared-lib$(MODE).dylib
else ifeq "$(PLAT)" "mingw"
  BGFX_MAKEFILE = .build/projects/gmake-mingw-gcc
  BGFX_BIN = bgfx/.build/win64_mingw-gcc/bin/
  BGFX_SHARED_LIB = bgfx-shared-lib$(MODE).dll
endif
BGFX_MAKE_CMD = make -R -C bgfx/$(BGFX_MAKEFILE) config=$(MODE)64 -j8

bx:
	$(BGFX_MAKE_CMD) bx

bimg:
	$(BGFX_MAKE_CMD) bimg

bgfx: bx
	$(BGFX_MAKE_CMD) bgfx

bimg_decode: bimg bx
	$(BGFX_MAKE_CMD) bimg_decode

bgfx-shared-lib: bgfx bimg bimg_decode
	$(BGFX_MAKE_CMD) bgfx-shared-lib

tools: bgfx
	$(BGFX_MAKE_CMD) shaderc texturec

runtime_make: bx bimg bgfx bimg_decode

TOOLSDIR = ../bin/$(PLAT)/$(MODE)

toolsdir:
	mkdir -p $(TOOLSDIR)

editor_make: runtime_make bgfx-shared-lib tools | toolsdir
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
GENIE_PLATFORM= --gcc=osx gmake
else
GENIE_PLATFORM= --os=windows --gcc=mingw-gcc gmake
endif

init:
	$(GENIE) $(GENIE_WITH_EDITOR) $(GENIE_PLATFORM)

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
