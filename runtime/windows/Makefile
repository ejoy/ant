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

firmware.o : firmware.rc
	windres $< $@

ant.exe : main.o firmware.o $(ANT)/clibs/ant/libant.a
	gcc -o $@ $^ $(LINKLIBANT) -lshlwapi
	strip --strip-unneeded $@ 

clean :
	rm -f *.o && rm -f ant.exe
