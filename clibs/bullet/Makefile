# Use make BGFXROOT=your_bgfx_path
BGFXROOT = ../../../ant3rd
BGFXSRC = $(BGFXROOT)/bgfx
BXSRC = $(BGFXROOT)/bx
BIMGSRC = $(BGFXROOT)/bimg
LUAINC = -I ../lua
LUALIB = -L ../lua -llua53

BULLETROOT = $(BGFXROOT)
BULLETINC = -I$(BULLETROOT)/bullet3/src 
BULLETLIB = -L$(BULLETROOT)/build/bullet3/lib -lBulletDynamics -lBulletCollision -lLinearMath -lstdc++ -lHACD
# -lBullet3Common -lBullet3Collision
# bullet3 could not be used this time 


ODIR = obj

CC= gcc
CXX = g++
CFLAGS = -O2 -Wall -Wno-misleading-indentation -Wno-unused-but-set-variable

# removed unrefrenced error 
# __cxa_guard_acquire,__cxa_guard_release 
#CXXFLAGS_STD = -std=c++14
#CXXFLAGS_STD += -std=gnu++11

mingw : lbullet.dll

# bgfx
#BGFXVER = Debug
BGFXVER = Release
BGFXLIB = -L$(BGFXSRC)/.build/win64_mingw-gcc/bin -lbgfx$(BGFXVER) -lbimg$(BGFXVER) -lbx$(BGFXVER) -lstdc++ -lgdi32 -lpsapi -luuid
BGFXINC = -I$(BGFXSRC)/include -I$(BXSRC)/include/compat/mingw -I$(BXSRC)/include
#BGFXUTILLIB = -lexample-common$(BGFXVER)
#BGFX3RDINC = -I$(BGFXSRC)/3rdparty

#$(ODIR)/CollisionSdkCTest.o : Collision/CollisionSdkCTest.cpp | $(ODIR)
#	$(CXX) $(CFLAGS) -std=c++11 -c -o $@ $^ $(BULLETINC) 

$(ODIR)/CollisionSdkC_Api.o : Collision/CollisionSdkC_Api.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -std=c++11 -c -o $@ $^ $(BULLETINC) 

$(ODIR)/Bullet2CollisionSdk.o : Collision/Internal/Bullet2CollisionSdk.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -std=c++11 -c -o $@ $^ $(BULLETINC)

#$(ODIR)/RealTimeBullet3CollisionSdk.o : Collision/Internal/RealTimeBullet3CollisionSdk.cpp | $(ODIR)
#	$(CXX) $(CFLAGS) -std=c++11 -c -o $@ $^ $(BULLETINC)

$(ODIR)/bullet.o : bullet.cpp | $(ODIR)
	$(CXX) $(CFLAGS)  -std=c++11 -c -DLUA_BUILD_AS_DLL -o $@ $^ $(LUAINC) $(BULLETINC)
#$(BGFXINC) $(BGFX3RDINC)

lbullet.dll : $(ODIR)/bullet.o  $(ODIR)/CollisionSdkC_Api.o $(ODIR)/Bullet2CollisionSdk.o 
#$(ODIR)/RealTimeBullet3CollisionSdk.o $(ODIR)/CollisionSdkCTest.o 
	$(CC) $(CFLAGS) --shared -o $@ $^ $(LUALIB) $(BULLETLIB) 
#$(BGFXUTILLIB) $(BGFXLIB) 


# all

$(ODIR) :
	mkdir $@

clean :
	rm -rf $(ODIR) && rm -f *.dll
