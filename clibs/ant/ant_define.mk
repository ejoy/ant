BUILD_CONFIG = Release

include $(ANT3RD)/../clibs/bgfx/bgfx_define.mk
include $(ANT3RD)/../clibs/hierarchy/ozz_define.mk

LINKLIBBGFX= $(BGFXUTILLIB) $(BIMGLIB) $(BGFXLIB)
LINKLIBBULLET= -L$(ANT3RD)/build/bullet3/lib -lBulletDynamics -lBulletCollision -lLinearMath -lstdc++ -lHACD
LINKLIBOZZ= $(OZZSAMPLE) $(OZZRUNTIME) $(OZZOFFLINE) $(OZZGEOMERTY) $(OZZBASE)

LINKLIBANT= $(LINKLIBBGFX) $(LINKLIBBULLET) $(LINKLIBOZZ) -lws2_32 -lstdc++
