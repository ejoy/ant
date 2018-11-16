ANT= ../..
ANT3RD= $(ANT)/3rd
include $(ANT)/clibs/ant/ant_define.mk

ANTINC= -I$(ANT)/clibs/ant
LUAINC= -I$(ANT)/clibs/lua
CFLAGS= -O2 -Wall -fPIC

default : ant.exe

mingw : default

main.o : main.cpp mingw_wmain.h
	g++ -std=c++17 -c $(CFLAGS) $(ANTINC) $(LUAINC) -o $@ $<

firmware :
	windres firmware.rc firmware.o

libant.a :
#	cd $(ANT)/clibs/ant/ && $(MAKE)

ant.exe : main.o libant.a firmware
	gcc -o $@ main.o firmware.o $(ANT)/clibs/ant/libant.a $(LINKLIBANT) -lshlwapi
	strip --strip-unneeded $@ 

clean :
	rm -f *.o && rm -f ant.exe
