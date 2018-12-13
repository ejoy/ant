include ../common.mk

CFLAGS = -O2 -Wall

mingw : filewatch.dll

fsevent.h : fsevent_win.h

unicode.o : unicode.cpp unicode.h
	$(CXX) -c -std=c++17 $(CFLAGS) $(LUAINC) -o $@ $<

fsevent_win.o : fsevent_win.cpp fsevent_win.h unicode.h lockqueue.h
	$(CXX) -c -std=c++17 $(CFLAGS) $(LUAINC) -o $@ $<

fsevent_osx.o : fsevent_osx.cpp fsevent_osx.h lockqueue.h semaphore.h
	$(CXX) -c -std=c++17 $(CFLAGS) $(LUAINC) -o $@ $<

lfilewatch.o : lfilewatch.cpp fsevent.h
	$(CXX) -c -std=c++17 $(CFLAGS) $(LUAINC) -o $@ $<

ifeq "$(PLAT)" "mingw"
filewatch.dll : lfilewatch.o fsevent_win.o unicode.o 
	$(CXX) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB) -lstdc++fs
else ifeq "$(PLAT)" "osx"
filewatch.dll : lfilewatch.o fsevent_osx.o
	$(CXX) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)
endif
clean :
	rm -f filewatch.dll
