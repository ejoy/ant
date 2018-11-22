include ../common.mk

CFLAGS = -O2 -Wall

mingw : debugger.dll

hookmgr.o : hookmgr.cpp thunk.h
	g++ -c -std=c++17 $(CFLAGS) $(LUAINC) -o $@ $<

event_free.o : event_free.cpp event_free.h
	g++ -c -std=c++17 $(CFLAGS) $(LUAINC) -o $@ $<

thunk.o : thunk.cpp thunk.h thunk_windows.inl thunk_windows_i386.inl thunk_windows_amd64.inl thunk_linux_amd64.inl thunk_other.inl
	g++ -c -std=c++17 $(CFLAGS) $(LUAINC) -o $@ $<

debugger.dll : hookmgr.o event_free.o thunk.o
	g++ --shared $(CFLAGS) $(LUAINC) -o $@ $^ $(LUALIB)

libdebugger.a : hookmgr.o event_free.o thunk.o
	ar rsv $@ $^

clean :
	rm -f debugger.dll
