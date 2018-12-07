include ../common.mk

ifeq "$(PLAT)" "mingw"
default : protocol.dll
else
default : libprotocol-$(PLAT).a
endif

$(ODIR)/lprotocol.o : lprotocol.c | $(ODIR)
	$(CC) -c $(CFLAGS) -o $@ $^ $(LUAINC)

protocol.dll : $(ODIR)/lprotocol.o
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

libprotocol-$(PLAT).a : $(ODIR)/lprotocol.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a

