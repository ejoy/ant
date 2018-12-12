ANT= ../..
PLAT=mingw
ANT3RD= $(ANT)/3rd
include $(ANT)/clibs/common.mk
include $(ANT)/clibs/ant/ant_define.mk

ANTINC= -I$(ANT)/clibs/ant
LUAINC= -I$(ANT)/clibs/lua
CFLAGS= -O2 -Wall -fPIC

default : ant.exe

mingw : default

main.o : main.c mingw_wmain.h
	$(CC) -c $(CFLAGS) $(ANTINC) $(LUAINC) -o $@ $<

libant-$(PLAT).a :
	cd $(ANT)/clibs/ant/ && $(MAKE) "PLAT=$(PLAT)" $@

ant.exe : main.o libant-$(PLAT).a
	$(CC) -o $@ main.o $(ANT)/clibs/ant/libant-$(PLAT).a $(LINKLIBANT) -lshlwapi
	$(STRIP) $@ 

clean :
	rm -f *.o && rm -f ant.exe
