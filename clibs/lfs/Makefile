LUAINC = -I ../lua
LUALIB = -L ../lua -llua53
CFLAGS = -O2 -Wall

mingw : lfs.dll

lfs.dll : lfs.c
	gcc --shared $(CFLAGS) $(LUAINC) -o $@ $^ $(LUALIB) -lshell32

clean :
	rm -f lfs.dll
