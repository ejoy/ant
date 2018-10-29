include ../common.mk

mingw : protocol.dll

protocol.dll : lprotocol.c
	gcc --shared $(CFLAGS) -o $@ $^ $(LUALIB) $(LUAINC)

clean :
	rm -f protocol.dll
