include ../common.mk

ifeq "$(PLAT)" "mingw"
default : remotedebug.dll
else
default : libremotedebug.a
endif

remotedebug.o : remotedebug.c debugvar.h
	$(CC) $(CFLAGS) -c -o $@ $< $(LUAINC)

remotedebug.dll : remotedebug.o
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB)

libremotedebug.a : remotedebug.o
	ar rsv $@ $^

clean :
	rm -f remotedebug.dll libremotedebug.a *.o
