# Use make BGFXROOT=your_bgfx_path
include ../common.mk
include ../bgfx/bgfx_define.mk

ifeq "$(PLAT)" "mingw"
default : lterrain.dll
else
default : libterrain-$(PLAT).a
endif

$(ODIR)/terrain.o : terrain.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(BGFXINC) $(BGFX3RDINC)

lterrain.dll : $(ODIR)/terrain.o 
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB) $(BGFXUTILLIB) $(BGFXLIB)

libterrain-$(PLAT).a : $(ODIR)/terrain.o 
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
