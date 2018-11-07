include ../common.mk
include ../bgfx/bgfx_define.mk

BULLETROOT = $(ANT3RD)
BULLETINC = -I$(BULLETROOT)/bullet3/src 
BULLETLIB = -L$(BULLETROOT)/build/bullet3/lib -lBulletDynamics -lBulletCollision -lLinearMath -lstdc++ -lHACD

mingw : bullet.dll

BULLET_SRC= Collision/CollisionSdkC_Api.cpp Collision/Internal/Bullet2CollisionSdk.cpp bullet.cpp
BULLET_OBJ= Collision/CollisionSdkC_Api.o Collision/Internal/Bullet2CollisionSdk.o bullet.o 

Collision/CollisionSdkC_Api.o : Collision/CollisionSdkC_Api.cpp
	gcc -c $(CFLAGS) $(CXXFLAGS) -o $@ $^ -lstdc++ $(LUALIB) $(BULLETLIB) $(BULLETINC) $(LUAINC)

Collision/Internal/Bullet2CollisionSdk.o : Collision/Internal/Bullet2CollisionSdk.cpp
	gcc -c $(CFLAGS) $(CXXFLAGS) -o $@ $^ -lstdc++ $(LUALIB) $(BULLETLIB) $(BULLETINC) $(LUAINC)

bullet.o : bullet.cpp
	gcc -c $(CFLAGS) $(CXXFLAGS) -o $@ $^ -lstdc++ $(LUALIB) $(BULLETLIB) $(BULLETINC) $(LUAINC)

bullet.dll : $(BULLET_OBJ) | $(ODIR)
	gcc --shared $(CFLAGS) $(CXXFLAGS) -o $@ $^ -lstdc++ $(LUALIB) $(BULLETLIB) $(BULLETINC) $(LUAINC)

libbullet.a : $(BULLET_OBJ) | $(ODIR)
	ar rsv $@ $^

$(ODIR) :
	mkdir $@

clean :
	rm -rf $(ODIR) && rm -f *.dll
