include ../common.mk

mingw : window.dll

window.o : window.c window.h
	$(CC) -g $(CFLAGS) -c -o $@ $< $(LUAINC)

window_native.o : window_native.c window_native.h window.h
	$(CC) -g $(CFLAGS) -c -o $@ $< $(LUAINC)

ifeq "$(PLAT)" "mingw"

PLAT_O = mingw_window.o
PLAT_LIB =
mingw_window.o : $(PLAT)/mingw_window.c window_native.h
	$(CC) -g $(CFLAGS) -c -o $@ $<

else ifeq "$(PLAT)" "osx"

PLAT_O = osx_window.o
PLAT_LIB = -framework Cocoa
osx_window.o : $(PLAT)/osx_window.m window_native.h
	$(CC) -g $(CFLAGS) -c -o $@ $<

endif

window.dll : window.o window_native.o $(PLAT_O)
	$(CC) $(CFLAGS) $(DYNLIB) -o $@ $^ $(PLAT_LIB)

libwindow.a : window.o window_native.o $(PLAT_O)
	ar rsv $@ $^

clean :
	rm -f window.dll *.o
