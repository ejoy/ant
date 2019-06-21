# Use make BGFXROOT=your_bgfx_path
include ../common.mk
include ../bgfx/bgfx_define.mk

ifeq "$(PLAT)" "mingw"
default : terrain.dll
else
default : $(ODIR)/libterrain.a
endif

GLM_DIR = -I$(ANT3RD)/glm
CLIBS = -I..

$(ODIR)/terrain.o : terrain.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(BGFXINC) $(BGFX3RDINC) $(CLIBS) $(GLM_DIR)

$(ODIR)/terrain.dll : $(ODIR)/terrain.o 
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB) $(BGFXUTILLIB) $(BGFXLIB)

$(ODIR)/libterrain.a : $(ODIR)/terrain.o 
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(ODIR) *.dll *.a
