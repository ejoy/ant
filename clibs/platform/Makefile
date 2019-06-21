include ../common.mk
include ../bgfx/bgfx_define.mk

ifeq "$(PLAT)" "mingw"
default : platform.dll
else
default : $(ODIR)/libplatform.a
endif

ifeq "$(PLAT)" "mingw"
PLAT_LIB = -lgdi32 -lstdc++
PLAT_CXX = cpp
else ifeq "$(PLAT)" "osx"
PLAT_LIB =
PLAT_CXX = mm
else ifeq "$(PLAT)" "ios"
PLAT_LIB =
PLAT_CXX = mm
endif

OBJS = $(ODIR)/lplatform.o $(ODIR)/platform_$(PLAT).o

$(ODIR)/platform_$(PLAT).o : platform_$(PLAT).$(PLAT_CXX) | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/lplatform.o : lplatform.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -I$(BXSRC)/include -o $@ $<

$(ODIR)/platform.dll : $(OBJS)
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB) $(PLAT_LIB)

$(ODIR)/libplatform.a : $(OBJS)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
