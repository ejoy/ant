LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CFLAGS = -O2 -Wall
THIRDINC = -I ../../../ant3rd/readerwriterqueue/

mingw : debugger.dll

debugger.dll : frontend.cpp backend.cpp
	g++ --shared $(CFLAGS) $(LUAINC) $(THIRDINC) -o $@ $^ $(LUALIB)

clean :
	rm -f debugger.dll
