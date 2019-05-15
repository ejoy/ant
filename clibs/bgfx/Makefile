include ../common.mk
include bgfx_define.mk

THREADINC=-I ../thread

ifeq "$(PLAT)" "mingw"
CFLAGS += -Wno-misleading-indentation -Wno-unused-but-set-variable
endif

ifeq "$(PLAT)" "mingw"
default : bgfx.dll
else
default : libbgfx-$(PLAT).a
endif

$(ODIR)/baselib.o : baselib.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(BGFXINC)

$(ODIR)/luabgfx.o : luabgfx.c  | $(ODIR)
	$(CC) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(THREADINC) $(LUAINC) $(BGFXINC)

$(ODIR)/luabgfxutil.o : luabgfxutil.c  | $(ODIR)
	$(CC) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(BGFXINC)

$(ODIR)/luabgfximgui.o : luabgfximgui.cpp  | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(BGFXINC) $(BGFX3RDINC)

bgfx.dll : $(ODIR)/luabgfx.o $(ODIR)/luabgfxutil.o $(ODIR)/baselib.o $(ODIR)/luabgfximgui.o
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB) $(BGFXLIB) $(BGFXUTILLIB)

libbgfx-$(PLAT).a : $(ODIR)/luabgfx.o $(ODIR)/luabgfxutil.o $(ODIR)/baselib.o $(ODIR)/luabgfximgui.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
