LUAINC = -I../lua
LUALIB = -L../lua -llua53
CFLAGS = -O2 -Wall

mingw : debugger.dll

thunk.cpp : thunk.h thunk_windows.inl thunk_windows_i386.inl thunk_windows_amd64.inl thunk_linux_amd64.inl thunk_other.inl

hookmgr.cpp : thunk.h

debugger.dll : hookmgr.cpp thunk.cpp
	g++ --shared $(CFLAGS) $(LUAINC) -o $@ $^ $(LUALIB)

clean :
	rm -f debugger.dll
