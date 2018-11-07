# Use make BGFXROOT=your_bgfx_path
include ../common.mk
include ../bgfx/bgfx_define.mk

mingw : lterrain.dll

# bgfx
#BGFXVER = Debug
BGFXVER = Release
BGFXLIB = -L$(BGFXSRC)/.build/win64_mingw-gcc/bin -lbgfx$(BGFXVER) -lbimg$(BGFXVER) -lbx$(BGFXVER) -lstdc++ -lgdi32 -lpsapi -luuid
BGFXINC = -I$(BGFXSRC)/include -I$(BXSRC)/include/compat/mingw -I$(BXSRC)/include
BGFXUTILLIB = -lexample-common$(BGFXVER)
BGFX3RDINC = -I$(BGFXSRC)/3rdparty


$(ODIR)/terrain.o : terrain.cpp | $(ODIR)
	$(CXX) $(CFLAGS)  -std=c++11 -c -DLUA_BUILD_AS_DLL -o $@ $^ $(LUAINC) $(BGFXINC) $(BGFX3RDINC)

lterrain.dll : $(ODIR)/terrain.o 
	$(CC) $(CFLAGS) --shared -o $@ $^ $(LUALIB) $(BGFXUTILLIB) $(BGFXLIB)


libterrain.a : $(ODIR)/terrain.o 
	ar rsv $@ $^

# all

$(ODIR) :
	mkdir $@

clean :
	rm -rf $(ODIR) && rm -f *.dll
