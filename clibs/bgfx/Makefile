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

$(ODIR)/baselib.o : baselib.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(BGFXINC)

$(ODIR)/luabgfx.o : luabgfx.c  | $(ODIR)
	$(CC) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(THREADINC) $(LUAINC) $(BGFXINC)

$(ODIR)/luabgfxutil.o : luabgfxutil.c  | $(ODIR)
	$(CC) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(BGFXINC)

$(ODIR)/bgfx-core.dll : bgfx-core.def
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(BGFXLIB)

$(ODIR)/bgfx.dll : $(ODIR)/luabgfx.o $(ODIR)/luabgfxutil.o $(ODIR)/baselib.o | $(ODIR)/bgfx-core.dll
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB)

$(ODIR)/libbgfx.a : $(ODIR)/luabgfx.o $(ODIR)/luabgfxutil.o $(ODIR)/baselib.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
