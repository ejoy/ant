include ../common.mk

default : snapshot.dll

$(ODIR)/snapshot.o : snapshot.c | $(ODIR)
	$(CC) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/snapshot.dll : $(ODIR)/snapshot.o
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

snapshot.dll : $(ODIR)/snapshot.dll | $(ODIR)
	cp $^ $@

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a

