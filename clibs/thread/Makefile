include ../common.mk

mingw : thread.dll

lthread.o : lthread.c
	gcc -c $(CFLAGS) -o $@ $^ $(LUAINC)

lseri.o : lseri.c
	gcc -c $(CFLAGS) -o $@ $^ $(LUAINC)

thread.dll : lthread.o lseri.o
	gcc --shared $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

libthread.a : lthread.o lseri.o
	ar rsv $@ $^

clean :
	rm -f thread.dll *.o
