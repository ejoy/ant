# Use make BGFXROOT=your_bgfx_path
include ../common.mk
include ../bgfx/bgfx_define.mk

ifeq "$(PLAT)" "mingw"
default : lterrain.dll
else
default : libterrain.a
endif

$(ODIR)/terrain.o : terrain.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(BGFXINC) $(BGFX3RDINC)

lterrain.dll : $(ODIR)/terrain.o 
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB) $(BGFXUTILLIB) $(BGFXLIB)

libterrain.a : $(ODIR)/terrain.o 
	ar rsv $@ $^

# all

$(ODIR) :
	mkdir $@

clean :
	rm -rf $(ODIR) && rm -f *.dll libterrain.a
