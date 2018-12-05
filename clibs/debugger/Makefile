include ../common.mk

ifeq "$(PLAT)" "mingw"
default : debugger.dll
else
default : libdebugger.a
endif

hookmgr.o : hookmgr.cpp thunk.h
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

event_free.o : event_free.cpp event_free.h
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

thunk.o : thunk.cpp thunk.h thunk_windows.inl thunk_windows_i386.inl thunk_windows_amd64.inl thunk_linux_amd64.inl thunk_other.inl
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

debugger.dll : hookmgr.o event_free.o thunk.o
	$(CXX) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)

libdebugger.a : hookmgr.o event_free.o thunk.o
	ar rsv $@ $^

clean :
	rm -f debugger.dll libdebugger.a *.o
