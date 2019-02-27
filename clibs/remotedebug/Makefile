include ../common.mk

ifeq "$(PLAT)" "mingw"
default : remotedebug.dll
else
default : libremotedebug-$(PLAT).a
endif

$(ODIR)/remotedebug.o : remotedebug.c debugvar.h | $(ODIR)
	$(CC) $(CFLAGS) -c -o $@ $< $(LUAINC)

$(ODIR)/visitor.o : visitor.c debugvar.h | $(ODIR)
	$(CC) $(CFLAGS) -c -o $@ $< $(LUAINC)

$(ODIR)/hookmgr.o : hookmgr.cpp thunk.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/event_free.o : event_free.cpp event_free.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/thunk.o : thunk.cpp thunk.h thunk_windows.inl thunk_windows_i386.inl thunk_windows_amd64.inl thunk_linux_amd64.inl thunk_other.inl | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

remotedebug.dll : $(ODIR)/remotedebug.o $(ODIR)/visitor.o $(ODIR)/hookmgr.o $(ODIR)/event_free.o $(ODIR)/thunk.o
	$(CXX) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB)

libremotedebug-$(PLAT).a : $(ODIR)/remotedebug.o $(ODIR)/visitor.o $(ODIR)/hookmgr.o $(ODIR)/event_free.o $(ODIR)/thunk.o
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
