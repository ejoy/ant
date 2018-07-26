LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CFLAGS = -O2 -Wall

mingw : debugger.dll

debugger.dll : frontend.cpp backend.cpp
	g++ --shared $(CFLAGS) $(LUAINC) -o $@ $^ $(LUALIB)

clean :
	rm -f debugger.dll
