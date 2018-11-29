include ../common.mk

CFLAGS= -O2 -Wall -fPIC
CC= g++ -std=c++17 -c

default : subprocess.dll

subprocess.h : subprocess_win.h subprocess_posix.h 

lsubprocess.o : lsubprocess.cpp subprocess.h
	$(CC) $(CFLAGS) $(LUAINC) -o $@ $<

subprocess_win.o : subprocess_win.cpp subprocess.h
	$(CC) $(CFLAGS) -o $@ $<

subprocess_posix.o : subprocess_posix.cpp subprocess.h
	$(CC) $(CFLAGS) -o $@ $<

ifeq "$(PLAT)" "mingw"
subprocess.dll : lsubprocess.o subprocess_win.o
	g++ $(LD_SHARED) $(LUALIB) -o $@ $^
	$(STRIP) $@
else ifeq "$(PLAT)" "osx"
subprocess.dll : lsubprocess.o subprocess_posix.o
	g++ $(LD_SHARED) $(LUALIB) -o $@ $^
	$(STRIP) $@
endif

clean :
	rm -f *.o subprocess.dll
