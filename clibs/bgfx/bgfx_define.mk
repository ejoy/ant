BGFXROOT = $(ANT3RD)
BGFXSRC = $(BGFXROOT)/bgfx
BXSRC 	= $(BGFXROOT)/bx
BIMGSRC = $(BGFXROOT)/bimg

ifeq ("$(BGFXROOT)","")
$(error BGFXROOT NOT define)
endif

ifeq ("$(BUILD_CONFIG)","")
$(error BUILD_CONFIG NOT define)
endif

#BGFXINC = -I$(BGFXSRC)/include -I$(BXSRC)/include/compat/$(PLAT) -I$(BXSRC)/include -I$(BGFXSRC)/src -I$(BGFXSRC)/examples/common -I$(BIMGSRC)/include
BGFXINC = -I$(BGFXSRC)/include -I$(BXSRC)/include/compat/$(PLAT) -I$(BXSRC)/include -I$(BGFXSRC)/src -I$(BIMGSRC)/include
BGFX3RDINC = -I$(BGFXSRC)/3rdparty

BXLIB = -lbx$(BUILD_CONFIG)
BIMG_DECODELIB = -lbimg_decode$(BUILD_CONFIG)
BIMGLIB = -lbimg$(BUILD_CONFIG)

ifeq "$(PLAT)" "mingw"
BGFXLIB = -L$(BGFXSRC)/.build/win64_mingw-gcc/bin -lbgfx$(BUILD_CONFIG) $(BXLIB) -lstdc++ -lgdi32 -lpsapi -luuid
else ifeq "$(PLAT)" "osx"
BGFXLIB = -L$(BGFXSRC)/.build/osx64_clang/bin -lbgfx$(BUILD_CONFIG) $(BXLIB) -lstdc++ -framework Foundation -framework Metal -framework QuartzCore -framework Cocoa
else ifeq "$(PLAT)" "ios"
BGFXLIB = -L$(BGFXSRC)/.build/ios-arm64/bin -lbgfx$(BUILD_CONFIG) $(BXLIB) -lstdc++
endif

BGFXUTILLIB = -lexample-common$(BUILD_CONFIG)
