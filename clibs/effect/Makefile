include ../common.mk
include ../bgfx/bgfx_define.mk

CLIBS_INC = -I..
ifeq "$(PLAT)" "mingw"
default : effect.dll
else
default : $(ODIR)/effect.a
endif

effect.dll : $(ODIR)/effect.dll
	cp $< $@

$(ODIR)/effect.o : effect.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(BXINC) $(BIMGINC) $(CLIBS_INC)

$(ODIR)/quadcache.o : quadcache.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) -o $@ $^ $(LUAINC) $(BXINC) $(BIMGINC) $(CLIBS_INC)

$(ODIR)/effect.dll : $(ODIR)/effect.o $(ODIR)/quadcache.o
	$(CXX) $(LD_SHARED) $(CFLAGS) $(CPPFLAGS) -o $@ $^ -lstdc++ -L$(BGFXLIBDIR) $(BIMGDECODELIB)  $(BIMGLIB) $(BXLIB) $(LUALIB)

$(ODIR)/libeffect.a : $(OBJS)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a