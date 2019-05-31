include ../common.mk


ifeq "$(PLAT)" "mingw"
default : filedialog.dll
else
default : libfiledialog-$(PLAT).a
endif

$(ODIR)/filedialog.o : filedialog.cpp | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

filedialog.dll : $(ODIR)/filedialog.o
	$(CC) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB) -lole32 -luuid -lstdc++

libfiledialog-$(PLAT).a : $(ODIR)/filedialog.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
