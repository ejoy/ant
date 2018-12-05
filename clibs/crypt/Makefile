include ../common.mk

ifeq "$(PLAT)" "mingw"
default : crypt.dll
else
default : libcrypt.a
endif

lua-crypt.o : lua-crypt.c
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

lsha1.o : lsha1.c
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

crypt.dll : lua-crypt.o lsha1.o
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

libcrypt.a : lua-crypt.o lsha1.o
	ar rsv $@ $^

clean :
	rm -f crypt.dll libcrypt.a *.o
