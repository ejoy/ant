include ../common.mk

ifeq "$(PLAT)" "mingw"
default : remotedebug.dll
RDEBUG_LUAFLAGS=-DLUA_BUILD_AS_DLL
else
default : libremotedebug-$(PLAT).a
endif

OBJS = $(ODIR)/rdebug_host.o $(ODIR)/rdebug_visitor.o $(ODIR)/rdebug_hookmgr.o $(ODIR)/rdebug_eventfree.o $(ODIR)/thunk.o

$(ODIR)/rdebug_host.o : rdebug_host.c | $(ODIR)
	$(CC) $(CFLAGS) -c -o $@ $< $(LUAINC) $(RDEBUG_LUAFLAGS)

$(ODIR)/rdebug_visitor.o : rdebug_visitor.c rdebug_debugvar.h | $(ODIR)
	$(CC) $(CFLAGS) -c -o $@ $< $(LUAINC)

$(ODIR)/rdebug_hookmgr.o : rdebug_hookmgr.cpp rdebug_eventfree.h thunk.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/rdebug_eventfree.o : rdebug_eventfree.cpp rdebug_eventfree.h | $(ODIR)
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
