BGFXROOT = ../../../ant3rd
BGFXSRC = $(BGFXROOT)/bgfx
BXSRC 	= $(BGFXROOT)/bx
BIMGSRC = $(BGFXROOT)/bimg

ifeq ("$(BUILD_CONFIG)","")
$(error BUILD_CONFIG need define)
endif

BGFXINC = -I$(BGFXSRC)/include -I$(BXSRC)/include/compat/mingw -I$(BXSRC)/include -I$(BGFXSRC)/src -I$(BGFXSRC)/examples/common -I$(BIMGSRC)/include
BGFX3RDINC = -I$(BGFXSRC)/3rdparty

BXLIB = -lbx$(BUILD_CONFIG)
BIMG_DECODELIB = -lbimg_decode$(BUILD_CONFIG)
BIMGLIB = -lbimg$(BUILD_CONFIG)
BGFXLIB = -L$(BGFXSRC)/.build/win64_mingw-gcc/bin -lbgfx$(BUILD_CONFIG) $(BIMGLIB) $(BXLIB) -lstdc++ -lgdi32 -lpsapi -luuid
BGFXUTILLIB = -lexample-common$(BUILD_CONFIG)