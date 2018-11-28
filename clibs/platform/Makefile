include ../common.mk
include ../bgfx/bgfx_define.mk

CFLAGS = -O2 -Wall

mingw : platform.dll

lplatform.o : lplatform.c
	gcc -c -std=gnu11 $(CFLAGS) $(LUAINC) -I$(BXSRC)/include -o $@ $<

platform.dll : lplatform.o
	g++ $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

libplatform.a : lplatform.o
	ar rsv $@ $^

clean :
	rm -f platform.dll *.o
