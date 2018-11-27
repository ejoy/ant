include ../common.mk

CFLAGS = -O2 -Wall

mingw : crypt.dll

lua-crypt.o : lua-crypt.c
	gcc -c $(CFLAGS) -o $@ $^ $(LUAINC)

lsha1.o : lsha1.c
	gcc -c $(CFLAGS) -o $@ $^ $(LUAINC)

crypt.dll : lua-crypt.o lsha1.o
	gcc $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

libcrypt.a : lua-crypt.o lsha1.o
	ar rsv $@ $^

clean :
	rm -f crypt.dll *.o
