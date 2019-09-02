include $(ANT3RD)/../clibs/bgfx/bgfx_define.mk
include $(ANT3RD)/../clibs/hierarchy/ozz_define.mk
include $(ANT3RD)/../clibs/bullet/bullet.mk

ifeq "$(PLAT)" "mingw"
PLAT_LIBS = -lws2_32 -limm32 -lole32 -loleaut32 -lwbemuuid
else
endif

LINKLIBBGFX= $(BGFXLIB) $(BIMGLIB) $(BXLIB)
LINKLIBBULLET= $(BULLETLIB) -lstdc++
LINKLIBOZZ= $(OZZRUNTIME) $(OZZOFFLINE) $(OZZGEOMERTY) $(OZZBASE)

LINKLIBANT= $(LINKLIBBGFX) $(LINKLIBBULLET) $(LINKLIBOZZ) -lstdc++ $(PLAT_LIBS)
