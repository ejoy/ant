include ../common.mk

CFLAGS = -O2 -Wall

mingw : filewatch.dll

fsevent.h : fsevent_win.h

unicode.o : unicode.cpp unicode.h
	g++ -c -std=c++17 $(CFLAGS) $(LUAINC) -o $@ $<

fsevent_win.o : fsevent_win.cpp fsevent_win.h unicode.h lockqueue.h
	g++ -c -std=c++17 $(CFLAGS) $(LUAINC) -o $@ $<

fsevent_osx.o : fsevent_osx.cpp fsevent_osx.h lockqueue.h semaphore.h
	g++ -c -std=c++17 $(CFLAGS) $(LUAINC) -o $@ $<

lfilewatch.o : lfilewatch.cpp fsevent.h
	g++ -c -std=c++17 $(CFLAGS) $(LUAINC) -o $@ $<

ifeq "$(PLAT)" "mingw"
filewatch.dll : lfilewatch.o fsevent_win.o unicode.o 
	g++ $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB) -lstdc++fs
else ifeq "$(PLAT)" "osx"
filewatch.dll : lfilewatch.o fsevent_osx.o
	g++ $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB) -lstdc++fs
endif
clean :
	rm -f filewatch.dll
