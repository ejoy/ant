include ../common.mk

ifeq "$(PLAT)" "mingw"
default : remotedebug.dll
else
default : libremotedebug-$(PLAT).a
endif

$(ODIR)/remotedebug.o : remotedebug.c debugvar.h | $(ODIR)
	$(CC) $(CFLAGS) -c -o $@ $< $(LUAINC)

remotedebug.dll : $(ODIR)/remotedebug.o
	$(CC) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB)

libremotedebug-$(PLAT).a : $(ODIR)/remotedebug.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
