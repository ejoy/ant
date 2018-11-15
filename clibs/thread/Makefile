include ../common.mk

mingw : thread.dll

lthread.o : lthread.c
	gcc -c $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

lseri.o : lseri.c
	gcc -c $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

thread.dll : lthread.o lseri.o
	gcc --shared $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

libthread.a : lthread.o lseri.o
	ar rsv $@ $^

clean :
	rm -f thread.dll *.o
