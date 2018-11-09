include ../common.mk

mingw : window.dll

window.dll : window.c windows_native.c
	$(CC) $(CFLAGS) --shared -o $@ $^ $(LUAINC) $(LUALIB)

clean :
	rm -f window.dll

