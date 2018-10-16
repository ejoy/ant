include ../common.mk
include ../bgfx/bgfx_define.mk

BULLETROOT = $(ANT3RD)
BULLETINC = -I$(BULLETROOT)/bullet3/src 
BULLETLIB = -L$(BULLETROOT)/build/bullet3/lib -lBulletDynamics -lBulletCollision -lLinearMath -lstdc++ -lHACD

mingw : bullet.dll

BULLET_SRC := Collision/CollisionSdkC_Api.cpp Collision/Internal/Bullet2CollisionSdk.cpp bullet.cpp
bullet.dll : $(BULLET_SRC) | $(ODIR)
	gcc --shared $(CFLAGS) $(CXXFLAGS) -o $@ $^ -lstdc++ $(LUALIB) $(BULLETLIB) $(BULLETINC) $(LUAINC)

$(ODIR) :
	mkdir $@

clean :
	rm -rf $(ODIR) && rm -f *.dll
