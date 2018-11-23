include ../common.mk

mingw : window.dll

window.o : window.c window.h
	$(CC) $(CFLAGS) -c -o $@ $< $(LUAINC)

ifeq "$(PLAT)" "osx"

PLAT_O = wnd_osx.o
PLAT_LIB = -framework Cocoa
wnd_osx.o : $(PLAT)/wnd_osx.m $(PLAT)/wnd_osx.h
	$(CC) $(CFLAGS) -c -o $@ $<

endif

wnd_native.o : $(PLAT)/wnd_native.c window.h
	$(CC) $(CFLAGS) -c -o $@ $< $(LUAINC)

window.dll : window.o wnd_native.o $(PLAT_O)
	$(CC) $(CFLAGS) $(DYNLIB) -o $@ $^ $(PLAT_LIB)

libwindow.a : window.o wnd_native.o $(PLAT_O)
	ar rsv $@ $^

clean :
	rm -f window.dll *.o
