include ../common.mk

BULLETROOT = $(ANT3RD)
BULLETINC = -I$(BULLETROOT)/bullet3/src 
BULLETLIB = -L$(BULLETROOT)/build/bullet3/lib -lBulletDynamics -lBulletCollision -lLinearMath -lstdc++ -lHACD

ifeq "$(PLAT)" "mingw"
default : bullet.dll
else
default : libbullet.a
endif

BULLET_SRC= Collision/CollisionSdkC_Api.cpp Collision/Internal/Bullet2CollisionSdk.cpp bullet.cpp
BULLET_OBJ= Collision/CollisionSdkC_Api.o Collision/Internal/Bullet2CollisionSdk.o bullet.o 

Collision/CollisionSdkC_Api.o : Collision/CollisionSdkC_Api.cpp
	$(CXX) -c $(CFLAGS) $(CXXFLAGS) -o $@ $^ $(BULLETINC) $(LUAINC)

Collision/Internal/Bullet2CollisionSdk.o : Collision/Internal/Bullet2CollisionSdk.cpp
	$(CXX) -c $(CFLAGS) $(CXXFLAGS) -o $@ $^ $(BULLETINC) $(LUAINC)

bullet.o : bullet.cpp
	$(CXX) -c $(CFLAGS) $(CXXFLAGS) -o $@ $^ $(BULLETINC) $(LUAINC)

bullet.dll : $(BULLET_OBJ) | $(ODIR)
	$(CXX) $(LD_SHARED) $(CFLAGS) $(CXXFLAGS) -o $@ $^ -lstdc++ $(LUALIB) $(BULLETLIB) $(BULLETINC)

libbullet.a : $(BULLET_OBJ)
	ar rsv $@ $^

$(ODIR) :
	mkdir $@

clean :
	rm -f $(BULLET_OBJ) && rm -f *.dll *.a 
