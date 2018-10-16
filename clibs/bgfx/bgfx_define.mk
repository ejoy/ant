BGFXROOT = ../../../ant3rd
BGFXSRC = $(BGFXROOT)/bgfx
BXSRC 	= $(BGFXROOT)/bx
BIMGSRC = $(BGFXROOT)/bimg

ifeq ("$(BUILD_CONFIG)","")
$(error BUILD_CONFIG need define)
endif

BGFXLIB = -L$(BGFXSRC)/.build/win64_mingw-gcc/bin -lbgfx$(BUILD_CONFIG) -lbimg$(BUILD_CONFIG) -lbx$(BUILD_CONFIG) -lstdc++ -lgdi32 -lpsapi -luuid
BGFXINC = -I$(BGFXSRC)/include -I$(BXSRC)/include/compat/mingw -I$(BXSRC)/include
BGFXUTILLIB = -lexample-common$(BUILD_CONFIG)
BGFX3RDINC = -I$(BGFXSRC)/3rdparty