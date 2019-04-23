include ../common.mk

ifeq "$(PLAT)" "mingw"
default : remotedebug.dll
else
default : libremotedebug-$(PLAT).a
endif

OBJS = $(ODIR)/rdebug_host.o $(ODIR)/rdebug_visitor.o $(ODIR)/rdebug_hookmgr.o $(ODIR)/rdebug_eventfree.o $(ODIR)/rdebug_redirect.o $(ODIR)/rdebug_stdio.o $(ODIR)/thunk.o

$(ODIR)/rdebug_host.o : rdebug_host.cpp | $(ODIR)
	$(CXX) $(CFLAGS) -c -o $@ $< $(LUAINC)

$(ODIR)/rdebug_visitor.o : rdebug_visitor.c rdebug_debugvar.h | $(ODIR)
	$(CC) $(CFLAGS) -c -o $@ $< $(LUAINC)

$(ODIR)/rdebug_hookmgr.o : rdebug_hookmgr.cpp rdebug_eventfree.h rdebug_timer.h thunk.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/rdebug_eventfree.o : rdebug_eventfree.cpp rdebug_eventfree.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/rdebug_redirect.o : rdebug_redirect.cpp rdebug_redirect.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/rdebug_stdio.o : rdebug_stdio.cpp rdebug_redirect.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/thunk.o : thunk.cpp thunk.h thunk_windows.inl thunk_windows_i386.inl thunk_windows_amd64.inl thunk_linux_amd64.inl thunk_other.inl | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

remotedebug.dll : $(OBJS)
	$(CXX) $(CFLAGS) $(LD_SHARED) -o $@ $^ $(LUALIB)

libremotedebug-$(PLAT).a : $(OBJS)
	ar rsv $@ $^

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(OROOT) *.dll *.a
