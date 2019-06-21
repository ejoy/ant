include ../common.mk

ifeq "$(PLAT)" "mingw"
default : crypt.dll
else
default : $(ODIR)/libcrypt.a
endif

$(ODIR)/lua-crypt.o : lua-crypt.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

$(ODIR)/lsha1.o : lsha1.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

$(ODIR)/crypt.dll : $(ODIR)/lua-crypt.o $(ODIR)/lsha1.o
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

$(ODIR)/libcrypt.a : $(ODIR)/lua-crypt.o $(ODIR)/lsha1.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
