include ../common.mk

ifeq "$(PLAT)" "mingw"
default : window.dll
else
default : $(ODIR)/libwindow.a
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

$(ODIR)/window.o : window.c window.h | $(ODIR)
	$(CC) -g $(CFLAGS) -c -o $@ $< $(LUAINC)

$(ODIR)/$(PLAT)_window.o : $(PLAT)/$(PLAT)_window.$(PLAT_C) $(PLAT)/$(PLAT)_window.h window.h  | $(ODIR)
	$(CC) -g $(CFLAGS) -c -o $@ $<

$(ODIR)/window.dll : $(ODIR)/window.o $(ODIR)/$(PLAT)_window.o
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(PLAT_LIB) $(LUALIB)

$(ODIR)/libwindow.a : $(ODIR)/window.o $(ODIR)/$(PLAT)_window.o
	ar rsv $@ $^

window.dll: $(ODIR)/window.dll | $(ODIR)
	cp $^ $@

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
