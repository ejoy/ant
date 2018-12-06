include ../common.mk

ifeq "$(PLAT)" "mingw"
default : window.dll
else
default : libwindow.a
endif

ifeq "$(PLAT)" "mingw"
PLAT_LIB =
PLAT_C = c
else ifeq "$(PLAT)" "osx"
PLAT_LIB = -framework Cocoa
PLAT_C = m
else ifeq "$(PLAT)" "ios"
PLAT_LIB =
PLAT_C = m
endif

window.o : window.c window.h
	$(CC) -g $(CFLAGS) -c -o $@ $< $(LUAINC)

window_native.o : window_native.c window_native.h window.h
	$(CC) -g $(CFLAGS) -c -o $@ $< $(LUAINC)

$(PLAT)_window.o : $(PLAT)/$(PLAT)_window.$(PLAT_C) window_native.h
	$(CC) -g $(CFLAGS) -c -o $@ $<

window.dll : window.o window_native.o $(PLAT)_window.o
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(PLAT_LIB) $(LUALIB)

libwindow.a : window.o window_native.o $(PLAT)_window.o
	ar rsv $@ $^

clean :
	rm -f window.dll libwindow.a *.o
