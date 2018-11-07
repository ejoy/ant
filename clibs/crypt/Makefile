LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CFLAGS = -O2 -Wall

mingw : crypt.dll

lua-crypt.o : lua-crypt.c
	gcc -c $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

lsha1.o : lsha1.c
	gcc -c $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

crypt.dll : lua-crypt.o lsha1.o
	gcc --shared $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

libcrypt.a : lua-crypt.o lsha1.o
	ar rsv $@ $^

clean :
	rm -f crypt.dll
