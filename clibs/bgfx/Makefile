include ../common.mk
include bgfx_define.mk

THREADINC=-I ../thread

ifeq "$(PLAT)" "mingw"
CFLAGS += -Wno-misleading-indentation -Wno-unused-but-set-variable
endif

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

$(ODIR)/bgfx.dll : $(ODIR)/luabgfx.o $(ODIR)/luabgfxutil.o $(ODIR)/bgfx_alloc.o
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB) -L$(BGFXLIBDIR) $(BXLIB) -lstdc++

$(ODIR)/libbgfx.a : $(ODIR)/luabgfx.o $(ODIR)/luabgfxutil.o $(ODIR)/bgfx_alloc.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
