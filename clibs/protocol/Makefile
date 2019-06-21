include ../common.mk

ifeq "$(PLAT)" "mingw"
default : protocol.dll
else
default : $(ODIR)/libprotocol.a
endif

$(ODIR)/lprotocol.o : lprotocol.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

$(ODIR)/protocol.dll : $(ODIR)/lprotocol.o
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

$(ODIR)/libprotocol.a : $(ODIR)/lprotocol.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a

