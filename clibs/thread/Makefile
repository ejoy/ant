include ../common.mk

ifeq "$(PLAT)" "mingw"
default : thread.dll
else
default : libthread.a
endif

lthread.o : lthread.c
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

lseri.o : lseri.c
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

thread.dll : lthread.o lseri.o
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

libthread.a : lthread.o lseri.o
	ar rsv $@ $^

clean :
	rm -f thread.dll libthread.a *.o
