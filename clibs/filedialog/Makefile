include ../common.mk


ifeq "$(PLAT)" "mingw"
default : filedialog.dll
else
default : $(ODIR)/libfiledialog.a
endif

$(ODIR)/filedialog.o : filedialog.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/filedialog.dll : $(ODIR)/filedialog.o
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB) -lole32 -luuid -lstdc++

$(ODIR)/libfiledialog.a : $(ODIR)/filedialog.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
