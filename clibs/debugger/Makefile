LUAINC = -I../lua
LUALIB = -L../lua -llua53
CFLAGS = -O2 -Wall

mingw : debugger.dll

hookmgr.o : hookmgr.cpp thunk.h
	g++ -c $(CFLAGS) $(LUAINC) -o $@ $< $(LUALIB)

event_free.o : event_free.cpp event_free.h
	g++ -c $(CFLAGS) $(LUAINC) -o $@ $< $(LUALIB)

thunk.o : thunk.cpp thunk.h thunk_windows.inl thunk_windows_i386.inl thunk_windows_amd64.inl thunk_linux_amd64.inl thunk_other.inl
	g++ -c $(CFLAGS) $(LUAINC) -o $@ $< $(LUALIB)

debugger.dll : hookmgr.o event_free.o thunk.o
	g++ --shared $(CFLAGS) $(LUAINC) -o $@ $^ $(LUALIB)

libdebugger.a : hookmgr.o event_free.o thunk.o
	ar rsv $@ $^

clean :
	rm -f debugger.dll
