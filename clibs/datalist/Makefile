include ../common.mk


ifeq "$(PLAT)" "mingw"
default : datalist.dll
else
default : $(ODIR)/libdatalist.a
endif

$(ODIR)/datalist.o : datalist.c | $(ODIR)
	$(CC) -c $(CFLAGS) $(LUAINC) -I$(BXSRC)/include -o $@ $<

$(ODIR)/datalist.dll : $(ODIR)/datalist.o
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

$(ODIR)/libdatalist.a : $(ODIR)/datalist.o
	ar rsv $@ $^

datalist.dll : $(ODIR)/datalist.dll
	cp $^ $@

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
