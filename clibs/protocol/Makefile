include ../common.mk

ifeq "$(PLAT)" "mingw"
default : protocol.dll
else
default : libprotocol.a
endif

lprotocol.o : lprotocol.c
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

protocol.dll : lprotocol.o
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

libprotocol.a : lprotocol.o
	ar rsv $@ $^

clean :
	rm -f protocol.dll libprotocol.a *.o
