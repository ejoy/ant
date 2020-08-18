ANT= ../..
ANT3RD= $(ANT)/3rd
include $(ANT)/clibs/common.mk
include $(ANT)/clibs/ant/ant_define.mk

default : $(ODIR)/libruntime.a

ifeq "$(PLAT)" "mingw"
$(ODIR)/set_current.o : set_current_win32.cpp set_current.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<
else ifeq "$(PLAT)" "osx"
$(ODIR)/set_current.o : set_current_osx.cpp set_current.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<
else ifeq "$(PLAT)" "ios"
$(ODIR)/set_current.o : set_current_ios.mm set_current.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<
endif

$(ODIR)/searcher.o : searcher.cpp searcher.h modules.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) $(BGFXINC) -o $@ $<

$(ODIR)/runtime.o : runtime.cpp runtime.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/libruntime.a : $(ODIR)/runtime.o $(ODIR)/searcher.o $(ODIR)/set_current.o | $(ODIR)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT)
