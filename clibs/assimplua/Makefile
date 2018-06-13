ASSIMPROOT = ../../..
BGFXROOT = $(ASSIMPROOT)
LUAINC = -I../lua
LUALIB = -L../lua -llua53
ASSIMP_BUILD_SUBPATH=""
ASSIMPINC = -I$(ASSIMPROOT)/assimp/include -I$(ASSIMPROOT)/assimp/$(ASSIMP_BUILD_SUBPATH)/include
ASSIMPLIB = -L$(ASSIMPROOT)/assimp/bin -L$(ASSIMPROOT)/assimp/$(ASSIMP_BUILD_SUBPATH)/code -llibassimp

BGFXSRC = $(BGFXROOT)/bgfx
BXSRC = $(BGFXROOT)/bx


CFLAGS = -O2 -Wall
ODIR = o
CXX = g++

mingw : assimplua.dll

BUILD_CFG = Release
BGFXLIB = -L$(BGFXSRC)/.build/win64_mingw-gcc/bin -lbgfx$(BUILD_CFG) -lbimg$(BUILD_CFG) -lbimg_decode$(BUILD_CFG) -lbx$(BUILD_CFG) -lstdc++ -lgdi32 -lpsapi -luuid \
-lbgfx-shared-lib$(BUILD_CFG)
BGFXUTILLIB = -lexample-common$(BUILD_CFG)

BXLIB = -lbx$(BUILD_CFG)
#BGFX3RDINC = -I$(BGFXSRC)/3rdparty
BGFXINC = -I$(BGFXSRC)/include -I$(BXSRC)/include -I$(BXSRC)/include/compat/mingw -I$(BGFXSRC)/src -I$(BGFXSRC)/examples/common
$(ODIR) : 
	mkdir $@

$(ODIR)/luaassimplua.o : assimplua.cpp  | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $^ -L. $(LUAINC) $(ASSIMPINC) $(BGFXINC)
	
assimplua.dll : $(ODIR)/luaassimplua.o
	$(CXX) $(CFLAGS) --shared -o $@ $^ -L. $(LUALIB) $(ASSIMPLIB) $(BGFXLIB) $(BGFXUTILLIB) $(BXLIB)
	
clean :
	rm -f assimplua.dll