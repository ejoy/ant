include ../common.mk
include bgfx_define.mk

THREADINC=-I ../thread

ifeq "$(PLAT)" "mingw"
CFLAGS += -Wno-misleading-indentation -Wno-unused-but-set-variable
endif

ifeq "$(PLAT)" "mingw"
default : bgfx.dll
else
default : libbgfx.a
endif


# bgfx
$(ODIR)/ibcompress.o : ibcompress.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $^ $(BGFXINC) $(BGFX3RDINC)

$(ODIR)/baselib.o : baselib.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(BGFXINC) $(BGFX3RDINC)

$(ODIR)/luabgfx.o : luabgfx.c  | $(ODIR)
	$(CC) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(THREADINC) $(LUAINC) $(BGFXINC)

$(ODIR)/luabgfxutil.o : luabgfxutil.c  | $(ODIR)
	$(CC) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(BGFXINC)

$(ODIR)/nuklearlua.o : nuklearlua.c | $(ODIR)
	$(CC) $(CFLAGS) -c $(LUA_FLAGS) -o $@ $^ $(LUAINC) $(BGFXINC)

bgfx.dll : $(ODIR)/luabgfx.o $(ODIR)/ibcompress.o $(ODIR)/luabgfxutil.o $(ODIR)/baselib.o $(ODIR)/nuklearlua.o
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB) $(BGFXUTILLIB) $(BGFXLIB) $(BIMGLIB) $(BXLIB)

libbgfx.a : $(ODIR)/luabgfx.o $(ODIR)/ibcompress.o $(ODIR)/luabgfxutil.o $(ODIR)/baselib.o $(ODIR)/nuklearlua.o
	ar rsv $@ $^

# all

$(ODIR) :
	mkdir $@

clean :
	rm -rf $(ODIR) && rm -f *.dll
