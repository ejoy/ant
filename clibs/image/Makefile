include ../common.mk
include ../bgfx/bgfx_define.mk

CLIBS_INC = -I..
ifeq "$(PLAT)" "mingw"
default : image.dll
else
default : $(ODIR)/image.a
endif

image.dll : $(ODIR)/image.dll
	cp $< $@

$(ODIR)/image.o : image.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(BIMGINC) $(CLIBS_INC)

OBJS = $(ODIR)/image.o

$(ODIR)/image.dll : $(OBJS)
	$(CXX) $(LD_SHARED) $(CFLAGS) $(CPPFLAGS) -o $@ $^ -lstdc++ -L$(BGFXLIBDIR) $(BIMGDECODELIB)  $(BIMGLIB) $(BXLIB) $(LUALIB)

$(ODIR)/libimage.a : $(OBJS)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a

test:
	../lua.exe test.lua