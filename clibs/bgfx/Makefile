include ../common.mk
include bgfx_define.mk

THREADINC=-I ../thread

# Use make BGFXROOT=your_bgfx_path
CFLAGS += -Wno-misleading-indentation -Wno-unused-but-set-variable

mingw : bgfx.dll

# bgfx
$(ODIR)/ibcompress.o : ibcompress.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -std=c++11 -c -o $@ $^ $(BGFXINC) $(BGFX3RDINC)

$(ODIR)/baselib.o : baselib.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -std=c++11 -c -DLUA_BUILD_AS_DLL -o $@ $^ $(LUAINC) $(BGFXINC) $(BGFX3RDINC)

$(ODIR)/luabgfx.o : luabgfx.c  | $(ODIR)
	$(CC) $(CFLAGS) -c -DLUA_BUILD_AS_DLL -o $@ $^ $(THREADINC) $(LUAINC) $(BGFXINC)

$(ODIR)/luabgfxutil.o : luabgfxutil.c  | $(ODIR)
	$(CC) $(CFLAGS) -c -DLUA_BUILD_AS_DLL -o $@ $^ $(LUAINC) $(BGFXINC)

$(ODIR)/nuklearlua.o : nuklearlua.c | $(ODIR)
	$(CC) $(CFLAGS) -c -DLUA_BUILD_AS_DLL -o $@ $^ $(LUAINC) $(BGFXINC)

bgfx.dll : $(ODIR)/luabgfx.o $(ODIR)/ibcompress.o $(ODIR)/luabgfxutil.o $(ODIR)/baselib.o $(ODIR)/nuklearlua.o
	$(CC) $(CFLAGS) --shared -o $@ $^ $(LUALIB) $(BGFXUTILLIB) $(BIMGLIB) $(BGFXLIB)

libbgfx.a : $(ODIR)/luabgfx.o $(ODIR)/ibcompress.o $(ODIR)/luabgfxutil.o $(ODIR)/baselib.o $(ODIR)/nuklearlua.o
	ar rsv $@ $^

# all

$(ODIR) :
	mkdir $@

clean :
	rm -rf $(ODIR) && rm -f *.dll
