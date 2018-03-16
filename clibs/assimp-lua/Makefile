ROOT = ../../..
LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
ASSIMPINC = -I $(ROOT)/assimp/include
ASSIMPLIB = -L $(ROOT)/assimp/bin -lassimp
BGFXSRC = $(ROOT)/bgfx
BXSRC = $(ROOT)/bx


CFLAGS = -O2 -Wall
ODIR = o
CXX = g++

mingw : assimplua.dll

BGFXVER = Release
BGFXLIB = -L$(BGFXSRC)/.build/win64_mingw-gcc/bin -lbgfx$(BGFXVER) -lbimg$(BGFXVER) -lbimg_decode$(BGFXVER) -lbx$(BGFXVER) -lstdc++ -lgdi32 -lpsapi -luuid \
-lbgfx-shared-lib$(BGFXVER)
BGFXUTILLIB = -lexample-common$(BGFXVER)
#BGFX3RDINC = -I$(BGFXSRC)/3rdparty
BGFXINC = -I$(BGFXSRC)/include -I$(BXSRC)/include -I$(BXSRC)/include/compat/mingw -I$(BGFXSRC)/src -I$(BGFXSRC)/examples/common

$(ODIR)/luaassimplua.o : assimplua.cpp  | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $^ -L. $(LUAINC) $(ASSIMPINC) $(BGFXINC)
	
assimplua.dll : $(ODIR)/luaassimplua.o
	$(CXX) $(CFLAGS) --shared -o $@ $^ -L. $(LUALIB) $(ASSIMPLIB) $(BGFXUTILLIB) $(BGFXLIB)
	cp -R assimplua.dll ../../bin
clean :
	rm -f assimplua.dll