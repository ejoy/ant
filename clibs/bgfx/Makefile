include ../common.mk
include bgfx_define.mk

THREADINC=-I ../thread

ifeq "$(PLAT)" "mingw"
default : bgfx.dll
else
default : $(ODIR)/libbgfx.a
endif

bgfx.dll : $(ODIR)/bgfx.dll
	cp $< $@

$(ODIR)/bgfx_alloc.o : bgfx_alloc.cpp bgfx_alloc.h | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(LUAINC) $(BGFXINC)

$(ODIR)/luabgfx.o : luabgfx.c bgfx_alloc.h | $(ODIR)
	$(CC) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $< $(THREADINC) $(LUAINC) $(BGFXINC)

$(ODIR)/luabgfxutil.o : luabgfxutil.c  | $(ODIR)
	$(CC) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(BGFXINC)

$(ODIR)/luabgfxui.o : luabgfxui.c  | $(ODIR)
	$(CC) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(BGFXINC) $(BGFX3RDINC)

$(ODIR)/bgfx.dll : $(ODIR)/luabgfx.o $(ODIR)/luabgfxutil.o $(ODIR)/bgfx_alloc.o $(ODIR)/luabgfxui.o
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB) -L$(BGFXLIBDIR) $(BGFXLIB) $(BXLIB) -lstdc++

$(ODIR)/libbgfx.a : $(ODIR)/luabgfx.o $(ODIR)/luabgfxutil.o $(ODIR)/bgfx_alloc.o $(ODIR)/luabgfxui.o
	ar rsv $@ $^

font.exe : font_manager.c
	$(CC) $(CFLAGS) -o $@ $^ $(BGFX3RDINC)

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
