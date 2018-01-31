LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CFLAGS = -g -Wall

mingw : winfile.dll

winfile.dll : winfile.c
	gcc --shared $(CFLAGS) $(LUAINC) -o $@ $^ $(LUALIB) -lshell32

clean :
	rm winfile.dll
