ANT= ../..
PLAT=osx
ANT3RD= $(ANT)/3rd
include $(ANT)/clibs/common.mk
include $(ANT)/clibs/ant/ant_define.mk

ANTINC= -I$(ANT)/clibs/ant
LUAINC= -I$(ANT)/clibs/lua
CFLAGS= -O2 -Wall -fPIC

default : ant.exe

mingw : default

main.o : main.cpp
	g++ -std=c++17 -c $(CFLAGS) $(ANTINC) $(LUAINC) -o $@ $<

libant.a :
#	cd $(ANT)/clibs/ant/ && $(MAKE)

ant.exe : main.o libant.a
	gcc -o $@ main.o $(ANT)/clibs/ant/libant.a $(LINKLIBANT)
	$(STRIP) $@ 

clean :
	rm -f *.o && rm -f ant.exe
