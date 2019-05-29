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
BGFX3RDINC = -I$(BGFXSRC)/3rdparty -I$(BGFXSRC)/examples/common

BXLIB = -lbx$(BUILD_CONFIG)
BIMG_DECODELIB = -lbimg_decode$(BUILD_CONFIG)
BIMGLIB = -lbimg$(BUILD_CONFIG)

IB_COMPRESSROOT:= $(ANT3RD)/ib-compress
IB_COMPRESSINC:= -I$(IB_COMPRESSROOT)
IB_COMPRESSLIB:= -L$(IB_COMPRESSROOT) -lib-compress-$(PLAT)

ifeq "$(PLAT)" "mingw"
BGFXLIBDIR = $(BGFXSRC)/.build/win64_mingw-gcc/bin
BGFXLIB = -L$(BGFXLIBDIR) -lbgfx$(BUILD_CONFIG) $(BIMGLIB) $(BXLIB) -lstdc++ -lgdi32 -lpsapi -luuid
else ifeq "$(PLAT)" "osx"
BGFXLIBDIR = -L$(BGFXSRC)/.build/osx64_clang/bin
BGFXLIB = $(BGFXLIBDIR) -lbgfx$(BUILD_CONFIG) $(BIMGLIB) $(BXLIB) -lstdc++
BGFXLIB += -framework Foundation -framework Metal -framework QuartzCore -framework Cocoa
else ifeq "$(PLAT)" "ios"
BGFXLIBDIR = $(BGFXSRC)/.build/ios-arm64/bin
BGFXLIB = -L$(BGFXLIBDIR) -lbgfx$(BUILD_CONFIG) $(BIMGLIB) $(BXLIB) -lstdc++
BGFXLIB += -framework CoreFoundation -framework Foundation -framework OpenGLES -framework UIKit -framework QuartzCore -weak_framework Metal
endif

BGFXUTILLIB = -lexample-common$(BUILD_CONFIG)
