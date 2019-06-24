ANT= ../..
PLAT=mingw
ANT3RD= $(ANT)/3rd
include $(ANT)/clibs/common.mk
include $(ANT)/clibs/ant/ant_define.mk

default : ant.exe

mingw : default

main.o : main.c mingw_wmain.h
	$(CC) -c $(CFLAGS) -I$(ANT)/clibs/ant -I$(ANT)/clibs/lua -o $@ $<

$(ODIR)/libant.a :
	cd $(ANT)/clibs/ant/ && $(MAKE) $@

ant.exe : main.o $(ODIR)/libant.a
	$(CC) -o $@ main.o $(ANT)/clibs/ant/$(ODIR)/libant.a $(LINKLIBANT) -lshlwapi
	$(STRIP) $@ 

clean :
	rm -f *.o
	rm -f ant.exe
	rm -rf $(ANT)/clibs/ant/o/$(PLAT)
