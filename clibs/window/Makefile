include ../common.mk

mingw : window.dll

window.o : window.c
	$(CC) $(CFLAGS) -c -o $@ $^ $(LUAINC) $(LUALIB)

windows_native.o : windows_native.c
	$(CC) $(CFLAGS) -c -o $@ $^ $(LUAINC) $(LUALIB)

window.dll : window.o windows_native.o
	$(CC) $(CFLAGS) --shared -o $@ $^ $(LUAINC) $(LUALIB)

libwindow.a : window.o windows_native.o
	ar rsv $@ $^

clean :
	rm -f window.dll

