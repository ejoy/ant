# Use make BGFXROOT=your_bgfx_path
include ../common.mk
include ../bgfx/bgfx_define.mk

ifeq "$(PLAT)" "mingw"
default : lterrain.dll
else
default : libterrain-$(PLAT).a
endif

GLM_DIR = -I$(ANT3RD)/glm

$(ODIR)/terrain.o : terrain.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(BGFXINC) $(BGFX3RDINC) $(GLM_DIR)

lterrain.dll : $(ODIR)/terrain.o 
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB) $(BGFXUTILLIB) $(BGFXLIB)

libterrain-$(PLAT).a : $(ODIR)/terrain.o 
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(ODIR) *.dll *.a
