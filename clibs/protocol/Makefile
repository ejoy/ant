include ../common.mk

mingw : protocol.dll

lprotocol.o : lprotocol.c
	gcc -c $(CFLAGS) -o $@ $^ $(LUAINC)

protocol.dll : lprotocol.o
	gcc $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

libprotocol.a : lprotocol.o
	ar rsv $@ $^

clean :
	rm -f protocol.dll *.o
