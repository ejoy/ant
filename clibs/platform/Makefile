include ../common.mk
include ../bgfx/bgfx_define.mk


ifeq "$(PLAT)" "mingw"
default : platform.dll
else
default : libplatform.a
endif

lplatform.o : lplatform.c
	$(CC) -c $(CFLAGS) $(LUAINC) -I$(BXSRC)/include -o $@ $<

platform.dll : lplatform.o
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

libplatform.a : lplatform.o
	ar rsv $@ $^

clean :
	rm -f platform.dll libplatform.a *.o
