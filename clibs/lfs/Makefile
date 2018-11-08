LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CFLAGS = -O2 -Wall

mingw : lfs.dll

lfs.o : lfs.c
	gcc -c $(CFLAGS) $(LUAINC) -o $@ $^ $(LUALIB) -lshell32

lfs.dll : lfs.c
	gcc --shared $(CFLAGS) $(LUAINC) -o $@ $^ $(LUALIB) -lshell32

liblfs.a : lfs.o
	ar rsv $@ $^

clean :
	rm -f lfs.dll
