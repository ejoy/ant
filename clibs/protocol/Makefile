include ../common.mk

mingw : protocol.dll

lprotocol.o : lprotocol.c
	gcc -c $(CFLAGS) -o $@ $^ $(LUAINC)

protocol.dll : lprotocol.o
	gcc --shared $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

libprotocol.a : lprotocol.o
	ar rsv $@ $^

clean :
	rm -f protocol.dll
