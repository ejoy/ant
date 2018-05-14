# Use make BGFXROOT=your_bgfx_path
BGFXROOT = ../../..
BGFXSRC = $(BGFXROOT)/bgfx
BXSRC = $(BGFXROOT)/bx
BIMGSRC = $(BGFXROOT)/bimg
LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
ODIR = o

CC= gcc
CXX = g++
CFLAGS = -O2 -Wall

mingw : bgfx.dll

# bgfx
#BGFXVER = Debug
BGFXVER = Release
BGFXLIB = -L$(BGFXSRC)/.build/win64_mingw-gcc/bin -lbgfx$(BGFXVER) -lbimg$(BGFXVER) -lbx$(BGFXVER) -lstdc++ -lgdi32 -lpsapi -luuid
BGFXINC = -I$(BGFXSRC)/include -I$(BXSRC)/include/compat/mingw -I$(BXSRC)/include
BGFXUTILLIB = -lexample-common$(BGFXVER)
BGFX3RDINC = -I$(BGFXSRC)/3rdparty

$(ODIR)/ibcompress.o : ibcompress.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -std=c++11 -c -o $@ $^ $(BGFXINC) $(BGFX3RDINC)

$(ODIR)/timer.o : timer.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -std=c++11 -c -DLUA_BUILD_AS_DLL -o $@ $^ $(LUAINC) $(BGFXINC) $(BGFX3RDINC)

$(ODIR)/luabgfx.o : luabgfx.c  | $(ODIR)
	$(CC) $(CFLAGS) -c -DLUA_BUILD_AS_DLL -o $@ $^ $(LUAINC) $(BGFXINC)

$(ODIR)/luabgfxutil.o : luabgfxutil.c  | $(ODIR)
	$(CC) $(CFLAGS) -c -DLUA_BUILD_AS_DLL -o $@ $^ $(LUAINC) $(BGFXINC)

bgfx.dll : $(ODIR)/luabgfx.o $(ODIR)/ibcompress.o $(ODIR)/luabgfxutil.o $(ODIR)/timer.o
	$(CC) $(CFLAGS) --shared -o $@ $^ $(LUALIB) $(BGFXUTILLIB) $(BIMGLIB) $(BGFXLIB)

# all

$(ODIR) :
	mkdir $@

clean :
	rm -rf $(ODIR) && rm -f *.dll
