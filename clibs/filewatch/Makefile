include ../common.mk

default : filewatch.dll

fsevent.h : fsevent_win.h

$(ODIR)/unicode.o : unicode.cpp unicode.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/fsevent_win.o : fsevent_win.cpp fsevent_win.h unicode.h lockqueue.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/fsevent_osx.o : fsevent_osx.cpp fsevent_osx.h lockqueue.h semaphore.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

$(ODIR)/lfilewatch.o : lfilewatch.cpp fsevent.h | $(ODIR)
	$(CXX) -c $(CFLAGS) $(LUAINC) -o $@ $<

ifeq "$(PLAT)" "mingw"
$(ODIR)/filewatch.dll : $(ODIR)/lfilewatch.o $(ODIR)/fsevent_win.o $(ODIR)/unicode.o 
	$(CXX) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB) -lstdc++fs
else ifeq "$(PLAT)" "osx"
$(ODIR)/filewatch.dll : $(ODIR)/lfilewatch.o $(ODIR)/fsevent_osx.o
	$(CXX) $(LD_SHARED) $(CFLAGS) -o $@ $^ $(LUALIB)
endif

filewatch.dll : $(ODIR)/filewatch.dll | $(ODIR)
	cp $^ $@

$(ODIR) :
	mkdir -p $@

clean :
	rm -rf $(ODIR) && rm -f *.dll && rm -f $(BULLET_OBJ)

