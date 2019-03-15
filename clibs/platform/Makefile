include ../common.mk
include ../bgfx/bgfx_define.mk


ifeq "$(PLAT)" "mingw"
default : platform.dll
else
default : libplatform-$(PLAT).a
endif

$(ODIR)/lplatform.o : lplatform.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -I$(BXSRC)/include -o $@ $<

platform.dll : $(ODIR)/lplatform.o
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

libplatform-$(PLAT).a : $(ODIR)/lplatform.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
