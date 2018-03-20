LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CFLAGS = -O2 -Wall

mingw : crypt.dll

crypt.dll : lua-crypt.c lsha1.c
	gcc --shared $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

clean :
	rm -f crypt.dll
