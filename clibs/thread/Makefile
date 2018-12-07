include ../common.mk

ifeq "$(PLAT)" "mingw"
default : thread.dll
else
default : libthread-$(PLAT).a
endif

$(ODIR)/lthread.o : lthread.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

$(ODIR)/lseri.o : lseri.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

thread.dll : $(ODIR)/lthread.o $(ODIR)/lseri.o
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

libthread-$(PLAT).a : $(ODIR)/lthread.o $(ODIR)/lseri.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
