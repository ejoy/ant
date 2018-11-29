include ../common.mk

CFLAGS = -O2 -Wall

mingw : filewatch.dll

fsevent.h : fsevent_win.h

fsevent_win.o : fsevent_win.cpp fsevent_win.h unicode.h lockqueue.h
	g++ -c -std=c++17 $(CFLAGS) $(LUAINC) -o $@ $<

unicode.o : unicode.cpp unicode.h
	g++ -c -std=c++17 $(CFLAGS) $(LUAINC) -o $@ $<

lfilewatch.o : lfilewatch.cpp fsevent.h
	g++ -c -std=c++17 $(CFLAGS) $(LUAINC) -o $@ $<

filewatch.dll : lfilewatch.o fsevent_win.o unicode.o
	g++ $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB) -lstdc++fs

clean :
	rm -f filewatch.dll
