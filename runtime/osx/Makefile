ANT= ../..
PLAT=osx
ANT3RD= $(ANT)/3rd
include $(ANT)/clibs/common.mk
include $(ANT)/clibs/ant/ant_define.mk

default : ant.exe

modules.o : ../common/modules.cpp ../common/modules.h
	$(CXX) -c $(CFLAGS) $(LUAINC) -I../common -o $@ $<

main.o : main.cpp mingw_wmain.h ../common/runtime.h
	$(CXX) -c $(CFLAGS) $(LUAINC) -I../common -o $@ $<

$(ODIR)/libant.a :
	cd $(ANT)/clibs/ant/ && $(MAKE) $@

$(ODIR)/libruntime.a :
	cd ../common/ && $(MAKE) $@

ant.exe : main.o modules.o $(ODIR)/libruntime.a $(ODIR)/libant.a
	$(CC) -o $@ main.o modules.o ../common/$(ODIR)/libruntime.a $(ANT)/clibs/ant/$(ODIR)/libant.a $(LINKLIBANT) && $(STRIP) $@

clean :
	rm -f *.o && rm -f ant.exe
