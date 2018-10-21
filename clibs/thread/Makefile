include ../common.mk

mingw : thread.dll

thread.dll : lthread.c lseri.c
	gcc --shared $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

clean :
	rm -f thread.dll
