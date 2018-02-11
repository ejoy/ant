LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CFLAGS = -O2 -Wall

mingw : redirectfd.dll

redirectfd.dll : redirectfd.c
	gcc --shared $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC) -lws2_32

clean :
	rm -f redirectfd.dll
