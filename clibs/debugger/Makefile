include ../common.mk

ifeq "$(PLAT)" "mingw"
default : debugger.dll
else
default : libdebugger-$(PLAT).a
endif

$(ODIR)/hookmgr.o : hookmgr.cpp thunk.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/event_free.o : event_free.cpp event_free.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/thunk.o : thunk.cpp thunk.h thunk_windows.inl thunk_windows_i386.inl thunk_windows_amd64.inl thunk_linux_amd64.inl thunk_other.inl | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

debugger.dll : $(ODIR)/hookmgr.o $(ODIR)/event_free.o $(ODIR)/thunk.o
	$(CXX) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

libdebugger-$(PLAT).a : $(ODIR)/hookmgr.o $(ODIR)/event_free.o $(ODIR)/thunk.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a

